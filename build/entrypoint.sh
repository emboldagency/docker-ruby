#!/bin/bash
set -e

# Migrate legacy ~/.gems -> canonical GEM_HOME and symlink to preserve compatibility
# This runs at container start to avoid breaking existing workspaces.
CANONICAL_BASE="/home/embold/.gem"
# Determine runtime ruby version. Prefer an explicit RUBY_VERSION env if supplied by the
# workspace (terraform injects this). Fall back to the ruby binary inside the image.
RUBY_RUNTIME_VERSION="${RUBY_VERSION:-$(ruby -e 'print RUBY_VERSION' 2>/dev/null || echo 3.4.6)}"
GEM_HOME_DIR="${CANONICAL_BASE}/ruby/${RUBY_RUNTIME_VERSION}"
LEGACY_DIR="/home/embold/.gems"

# Export dynamic GEM-related env so non-shell processes and later steps inherit them.
export RUBY_VERSION="$RUBY_RUNTIME_VERSION"
export GEM_HOME="$GEM_HOME_DIR"
export GEM_PATH="${GEM_HOME_DIR}:/opt/embold/image-gems/ruby/${RUBY_RUNTIME_VERSION}"
export PATH="${GEM_HOME_DIR}/bin:/opt/embold/image-gems/ruby/${RUBY_RUNTIME_VERSION}/bin:$PATH"

# GEM_HOME migration: Migrate legacy ~/.gems -> canonical GEM_HOME first
if [ "$(id -u)" -ne 0 ]; then
	version=$(basename "$GEM_HOME_DIR")
	legacy_version_dir="$LEGACY_DIR/$version"
	migration_marker="${LEGACY_DIR}.migrated.${version}.marker"

	echo "INFO: checking for gem migration from legacy .gems to canonical .gem for ruby $version"

	# Check if legacy gems exist and no migration has been done yet
	if [ -d "$legacy_version_dir" ] && [ ! -f "$migration_marker" ]; then
		echo "INFO: migrating legacy gems from $legacy_version_dir to $GEM_HOME_DIR"
		mkdir -p "$GEM_HOME_DIR"
		# Use rsync for robust migration (merge with any existing gems)
		rsync -a "$legacy_version_dir/" "$GEM_HOME_DIR/" || true

		# Ensure ownership is correct for embold user
		chown -R "$(id -u):$(id -g)" "$CANONICAL_BASE" || true

		# Create a migration marker to prevent re-migration
		touch "$migration_marker" 2>/dev/null || true
		echo "INFO: migration complete; marker: $migration_marker"
	elif [ -d "$LEGACY_DIR" ] && [ ! -f "$migration_marker" ] && [ ! -d "$GEM_HOME_DIR" ]; then
		# No exact match for this ruby version; look for any legacy version dirs and pick the highest
		candidate=$(ls -1 "$LEGACY_DIR" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true)
		if [ -n "$candidate" ] && [ -d "$LEGACY_DIR/$candidate" ]; then
			echo "WARN: legacy gems found for Ruby $candidate but not for $version; copying $candidate into $version (may be incompatible)"
			mkdir -p "$GEM_HOME_DIR"
			rsync -a "$LEGACY_DIR/$candidate/" "$GEM_HOME_DIR/" || true
			chown -R "$(id -u):$(id -g)" "$CANONICAL_BASE" || true
			touch "$migration_marker" 2>/dev/null || true
		fi
	else
		echo "INFO: no migration needed - either no legacy gems or migration already completed"
	fi
fi

# Seed an empty mounted home with prepared gems baked into the image
# This allows upgrading existing workspaces where /home/embold is a volume
# (the mount hides image content). We only seed when the target is absent
# or empty to avoid overwriting user data. Use a tmpdir + mv to avoid
# partial-copy races.
if [ "$(id -u)" -ne 0 ]; then
	if [ -d /opt/embold/image-gems ]; then
		if [ ! -d "$GEM_HOME_DIR" ] || [ -z "$(ls -A "$GEM_HOME_DIR" 2>/dev/null)" ]; then
			echo "INFO: Seeding $GEM_HOME_DIR from /opt/embold/image-gems"
			tmpdir="${GEM_HOME_DIR}.tmp.$$"
			rm -rf "$tmpdir" 2>/dev/null || true
			mkdir -p "$tmpdir"
			# Use rsync for robustness
			rsync -a "/opt/embold/image-gems/ruby/${RUBY_RUNTIME_VERSION}/" "$tmpdir/" || true
			# move into place atomically
			rm -rf "$GEM_HOME_DIR" 2>/dev/null || true
			mv "$tmpdir" "$GEM_HOME_DIR" 2>/dev/null || true
			if ! chown -R "$(id -u):$(id -g)" "$GEM_HOME_DIR" 2>/dev/null; then
				echo "WARN: failed to chown $GEM_HOME_DIR; permissions may need to be adjusted"
			fi
			echo "INFO: Seeding complete"
		else
			echo "INFO: $GEM_HOME_DIR already present, skipping seed"
		fi
	fi
fi

# After migration, ensure minimal runtime gems are present so executables like `pulsar` work.
# Install as non-root into the mounted GEM_HOME to persist into the user's volume.
if [ "$(id -u)" -ne 0 ]; then
	# Ensure gem binary uses our GEM_HOME/GEM_PATH
	if ! command -v pulsar >/dev/null 2>&1; then
		echo "INFO: pulsar not found in PATH; attempting to install required gems into $GEM_HOME"
		# Ensure gem (RubyGems) is available
		if command -v gem >/dev/null 2>&1; then
			# Install rake and pulsar if missing (use modern gem install syntax)
			if ! gem list -i rake >/dev/null 2>&1; then
				gem install --no-document rake || true
			fi
			if ! gem list -i pulsar-embold >/dev/null 2>&1; then
				# Try to install pulsar via specific_install if available, otherwise attempt normal install
				if gem list -i specific_install >/dev/null 2>&1; then
					gem specific_install https://github.com/emboldagency/pulsar-embold.git || true
				else
					gem install --no-document pulsar || true
				fi
			fi
		fi
	fi
fi

# Remove a potentially pre-existing server.pid for Rails.
rm -f /code/tmp/pids/server.pid

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"