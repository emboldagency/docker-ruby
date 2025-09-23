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
    # Ruby environment
    BUNDLE_APP_CONFIG=/home/embold/.gems/${RUBY_VERSION} \
    GEM_HOME=/home/embold/.gems/${RUBY_VERSION} \
    PATH=$PATH:/home/embold/.gems/${RUBY_VERSION}/bin

USER root

COPY --chown=embold:embold --chmod=774 coder /coder

# Final runtime image: install only runtime packages
# Install requirements with BuildKit cache mounts and transient policy to avoid starting services
RUN --mount=type=cache,target=/var/cache/apt/archives \
    # remove any stale locks and ensure apt/dpkg directories exist
    rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock || true && \
    mkdir -p /var/cache/apt/archives /var/lib/apt/lists /var/lib/dpkg /usr/share/postgresql-common/pgdg && \
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
    rm -rf /home/embold/.gems/${RUBY_VERSION}/cache

# Copy configuration files
COPY --chmod=775 entrypoint.sh /usr/bin/entrypoint.sh

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

FROM base AS final
ARG RUBY_VERSION
COPY --from=builder /usr/local /usr/local
RUN mkdir -p $GEM_HOME && \
    mkdir -p /home/embold/.gems/${RUBY_VERSION} && \
    gem install specific_install && \
    gem specific_install https://github.com/emboldagency/pulsar-embold.git && \
    gem install colorls && \
    rm -rf /home/embold/.gems/${RUBY_VERSION}/cache

# Run before starting to remove server.pid
ENTRYPOINT ["entrypoint.sh"]
