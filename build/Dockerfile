# syntax=docker/dockerfile:1.4

ARG UBUNTU_VERSION=24.04 \
    RUBY_VERSION=3.4.6

# Builder stage: install build deps and compile Ruby
FROM emboldcreative/base:ubuntu${UBUNTU_VERSION} AS builder

ARG RUBY_VERSION

USER root

# Avoid interactive prompts during package installs
ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt/archives \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    autoconf \
    bison \
    build-essential \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libyaml-dev \
    libffi-dev \
    libgdbm-dev \
    libncurses-dev \
    libsqlite3-dev \
    libjpeg-dev \
    libtiff-dev \
    libwebp-dev \
    libpq-dev && \
    # compile Ruby using ruby-build available in base image
    ruby-build ${RUBY_VERSION} /usr/local && \
    rm -rf /var/lib/apt/lists/*

FROM emboldcreative/base:ubuntu${UBUNTU_VERSION} AS base

ARG RUBY_VERSION

ENV LANG=en_US.utf8 \
    TZ=UTC \
    DATE_TIMEZONE=UTC \
    DEBIAN_FRONTEND=noninteractive \
    # Ruby environment (canonical: ~/.gem/ruby/<version>)
    BUNDLE_APP_CONFIG=/home/embold/.gem/ruby/${RUBY_VERSION} \
    GEM_HOME=/home/embold/.gem/ruby/${RUBY_VERSION} \
    # Include image-bundled gems so non-shell processes can find gems when /home is mounted
    GEM_PATH=/home/embold/.gem/ruby/${RUBY_VERSION}:/opt/embold/image-gems/ruby/${RUBY_VERSION} \
    PATH=/home/embold/.gem/ruby/${RUBY_VERSION}/bin:/opt/embold/image-gems/ruby/${RUBY_VERSION}/bin:$PATH

USER root

# Allow building from either repo root (pass CONTEXT_PREFIX=build/) or from the build/ directory (default empty)
ARG CONTEXT_PREFIX=""
COPY --chown=embold:embold --chmod=774 ${CONTEXT_PREFIX}coder /coder

# Final runtime layer for this image: install only runtime packages
# Install requirements with BuildKit cache mounts and transient policy to avoid starting services
RUN --mount=type=cache,target=/var/cache/apt/archives-ruby \
    # remove any stale locks and ensure apt/dpkg directories exist
    rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock || true && \
    mkdir -p /var/cache/apt/archives /var/lib/apt/lists /var/lib/dpkg /usr/share/postgresql-common/pgdg /usr/share/keyrings && \
    chmod 0755 /var/cache/apt/archives /var/lib/apt/lists /var/lib/dpkg && \
    dpkg --configure -a || true && \
    # add PostgreSQL apt repo key and source
    curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
    sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    # retry apt-get update/install a few times to avoid transient lock race conditions in BuildKit
    (for i in 1 2 3 4 5; do apt-get update && break || sleep 1; done) && \
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d && \
    (for i in 1 2 3 4 5; do apt-get install -y -q --no-install-recommends postgresql-client && break || sleep 1; done) && \
    rm -rf /var/lib/apt/lists/* && \
    # prune locales to keep only en_US to avoid copying unnecessary locale data into runtime
    if [ -d /usr/share/locale ]; then find /usr/share/locale -maxdepth 1 -mindepth 1 ! -name 'en_US' -exec rm -rf {} + || true; fi && \
    rm -rf /var/lib/apt/lists/* /usr/share/man/* /usr/share/doc/* /usr/share/doc-base/* && \
    rm -f /usr/sbin/policy-rc.d && \
    # Combine our configure scripts
    cd /coder && \
    cat scripts/configure-ruby >> scripts/configure && \
    if [ -d /home/embold/.gems/${RUBY_VERSION}/cache ]; then find /home/embold/.gems/${RUBY_VERSION}/cache -mindepth 1 -delete || true; fi

# Ensure env is available for login and non-login shells
RUN printf 'export GEM_HOME=%s\nexport GEM_PATH=%s\nexport PATH=%s/bin:$PATH\n' \
    "/home/embold/.gem/ruby/${RUBY_VERSION}" \
    "/home/embold/.gem/ruby/${RUBY_VERSION}:/opt/embold/image-gems/ruby/${RUBY_VERSION}" \
    "/home/embold/.gem/ruby/${RUBY_VERSION}:/opt/embold/image-gems/ruby/${RUBY_VERSION}" > /etc/profile.d/embold-gems.sh && \
    chmod 0755 /etc/profile.d/embold-gems.sh

# Copy configuration files
COPY --chmod=775 ${CONTEXT_PREFIX}entrypoint.sh /usr/bin/entrypoint.sh

USER embold

FROM base AS ruby3.4.6
COPY --from=builder /usr/local /usr/local

FROM base AS ruby3.3.9
COPY --from=builder /usr/local /usr/local

FROM base AS ruby3.2.9
COPY --from=builder /usr/local /usr/local

FROM base AS ruby3.1.7
COPY --from=builder /usr/local /usr/local

FROM base AS ruby3.0.7
COPY --from=builder /usr/local /usr/local

FROM base AS ruby2.7.8
COPY --from=builder /usr/local /usr/local
RUN gem install public_suffix:5.1.1 dotenv:2.8.1 --conservative

FROM builder AS ruby_gems
ARG RUBY_VERSION
# Install built gems directly into /opt/embold/image-gems to avoid copying later.
ENV GEM_HOME=/opt/embold/image-gems/ruby/${RUBY_VERSION}
ENV PATH=$GEM_HOME/bin:/usr/local/bin:$PATH
RUN --mount=type=cache,id=gem-cache-${RUBY_VERSION},target=/opt/embold/image-gems/ruby/${RUBY_VERSION}/cache \
    mkdir -p $GEM_HOME && \
    echo 'gem: --no-document' > /etc/gemrc && \
    # Update RubyGems system first (requires root in build stage), then install runtime gems in one call.
    # Installing multiple gems in a single `gem install` reduces duplication and is executed as root in the builder.
    gem update --system && \
    gem install --no-document bundler rails specific_install colorls rake && \
    # Install pulsar from its repository using specific_install (available after the previous install)
    gem specific_install https://github.com/emboldagency/pulsar-embold.git && \
    # Remove duplicate binstubs that `gem update --system` may have placed in /usr/local/bin
    # Keep /usr/local/bin/gem to avoid breaking RubyGems tooling
    rm -f /usr/local/bin/bundle /usr/local/bin/bundler || true && \
    if [ -d "$GEM_HOME/cache" ]; then find "$GEM_HOME/cache" -mindepth 1 -delete || true; fi

FROM base AS final
ARG RUBY_VERSION
COPY --from=builder /usr/local /usr/local
# Keep a read-only image-bundled gem tree under /opt so we can seed an empty mounted home on first-run.
# Gems were installed in the ruby_gems stage directly into /opt/embold/image-gems.
COPY --chown=embold:embold --from=ruby_gems /opt/embold/image-gems/ /opt/embold/image-gems/
RUN chown -R embold:embold /opt/embold/image-gems || true

# Run before starting to remove server.pid. Use absolute path for robustness.
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
