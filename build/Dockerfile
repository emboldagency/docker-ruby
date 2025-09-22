# syntax=docker/dockerfile:1.4

ARG UBUNTU_VERSION=24.04 \
    RUBY_VERSION=3.4.6

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

COPY --chown=embold:embold --chmod=774 build/coder /coder

# Install requirements with BuildKit cache mounts and transient policy to avoid starting services
RUN --mount=type=cache,target=/var/cache/apt/archives \
    install -d /usr/share/postgresql-common/pgdg && \
    curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
    sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    apt-get update && \
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d && \
    apt-get install -y -q --no-install-recommends \
    libjpeg-dev \
    libpq-dev \
    libtiff-dev \
    libwebp-dev \
    postgresql-client \
    rm -rf /var/lib/apt/lists/* && \
    # prune locales to keep only en_US to avoid copying unnecessary locale data into runtime
    if [ -d /usr/share/locale ]; then find /usr/share/locale -maxdepth 1 -mindepth 1 ! -name 'en_US' -exec rm -rf {} + || true; fi && \
    rm -rf /var/lib/apt/lists/* /usr/share/man/* /usr/share/doc/* /usr/share/doc-base/* && \
    rm -f /usr/sbin/policy-rc.d && \
    # Combine our configure scripts
    cd /coder && \
    cat scripts/configure-ruby >> scripts/configure && \
    # Install Ruby
    ruby-build ${RUBY_VERSION} /usr/local && \
    rm -rf /home/embold/.gems/${RUBY_VERSION}/cache

# Copy configuration files
COPY --chmod=775 build/entrypoint.sh /usr/bin/entrypoint.sh

USER embold

FROM base AS ruby3.3.9

FROM base AS ruby3.3.4

FROM base AS ruby3.2.5

FROM base AS ruby3.1.6

FROM base AS ruby3.0.7

FROM base AS ruby2.7.8

RUN gem install public_suffix:5.1.1 dotenv:2.8.1 --conservative

FROM ruby${RUBY_VERSION} AS final

RUN mkdir -p $GEM_HOME && \
    mkdir -p /home/embold/.gems/${RUBY_VERSION} && \
    gem install specific_install && \
    gem specific_install https://github.com/emboldagency/pulsar-embold.git && \
    gem install colorls && \
    rm -rf /home/embold/.gems/${RUBY_VERSION}/cache

# Run before starting to remove server.pid
ENTRYPOINT ["entrypoint.sh"]
