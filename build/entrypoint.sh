#!/bin/bash
set -e

# Migrate legacy ~/.gems -> canonical GEM_HOME and symlink to preserve compatibility
# This runs at container start to avoid breaking existing workspaces.
CANONICAL_BASE="/home/embold/.gem"
GEM_HOME_DIR="${GEM_HOME:-${CANONICAL_BASE}/ruby/$(ruby -e 'print RUBY_VERSION' 2>/dev/null || echo 3.4.6)}"
LEGACY_DIR="/home/embold/.gems"

# Only run migration for non-root user to avoid interfering with image builds
if [ "$(id -u)" -ne 0 ]; then
	if [ -d "$LEGACY_DIR" ]; then
		# Resolve canonical paths where possible
		real_legacy=$(readlink -f "$LEGACY_DIR" 2>/dev/null || echo "$LEGACY_DIR")
		real_gem_home=$(readlink -f "$GEM_HOME_DIR" 2>/dev/null || echo "$GEM_HOME_DIR")

		# If GEM_HOME is the same as legacy, nothing to do
		if [ "$real_legacy" != "$real_gem_home" ]; then
			mkdir -p "$GEM_HOME_DIR"
			shopt -s dotglob 2>/dev/null || true

			# If GEM_HOME is nested under legacy (e.g. /home/embold/.gems/3.4.6),
			# avoid removing the parent or creating a symlink that would cause recursion.
			case "$real_gem_home" in
				"$real_legacy"/*)
								for f in "$LEGACY_DIR"/* "$LEGACY_DIR"/.[!.]* "$LEGACY_DIR"/?*; do
						[ -e "$f" ] || continue
						# skip moving the gem_home directory itself
						if [ "$(readlink -f "$f")" = "$real_gem_home" ]; then
							continue
						fi
									mv -n "$f" "$GEM_HOME_DIR/" 2>/dev/null || true
					done
					chown -R "$(id -u):$(id -g)" "$GEM_HOME_DIR" || true
					;;
				*)
					# GEM_HOME is not nested; move everything and symlink legacy -> gem_home
					for f in "$LEGACY_DIR"/* "$LEGACY_DIR"/.[!.]* "$LEGACY_DIR"/?*; do
						[ -e "$f" ] || continue
									mv -n "$f" "$GEM_HOME_DIR/" 2>/dev/null || true
					done
								# remove legacy dir and symlink to the canonical base
								rm -rf "$LEGACY_DIR"
								mkdir -p "$CANONICAL_BASE"
								ln -s "$CANONICAL_BASE" "$LEGACY_DIR" || true
								chown -hR "$(id -u):$(id -g)" "$GEM_HOME_DIR" "$LEGACY_DIR" || true
					;;
			esac
		fi
	fi
fi

# Remove a potentially pre-existing server.pid for Rails.
rm -f /code/tmp/pids/server.pid

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"