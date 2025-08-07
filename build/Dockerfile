ARG UBUNTU_VERSION=24.04 \
    RUBY_VERSION=3.3.4

FROM emboldcreative/base:ubuntu${UBUNTU_VERSION} AS base

ARG RUBY_VERSION

ENV BUNDLE_APP_CONFIG=/home/embold/.gems/${RUBY_VERSION} \
    GEM_HOME=/home/embold/.gems/${RUBY_VERSION} \
    PATH=$PATH:/home/embold/.gems/${RUBY_VERSION}/bin

USER root

COPY --chown=embold:embold --chmod=774 coder /coder

# Install requirements
RUN --mount=type=secret,id=GH_PACKAGES_TOKEN \
    GH_PACKAGES_TOKEN=$(cat /run/secrets/GH_PACKAGES_TOKEN) && \
    install -d /usr/share/postgresql-common/pgdg && \
    curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
    sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    apt-get update && \
    apt-get install -y -q --no-install-recommends \
    imagemagick \
    libjpeg-dev \
    libpq-dev \
    libtiff-dev \
    libvips \
    libwebp-dev \
    postgresql-client \
    tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    # Combine our configure scripts
    cd /coder && \
    cat scripts/configure-ruby >> scripts/configure && \
    # Install Ruby
    ruby-build ${RUBY_VERSION} /usr/local && \
    mkdir -p $GEM_HOME && \
    chown -R embold:embold $GEM_HOME && \
    # --- Install Ruby gems with GitHub authentication ---
    echo -e "---\n:github: Bearer ${GH_PACKAGES_TOKEN}" > /home/embold/.gem/credentials && \
    chmod 0600 /home/embold/.gem/credentials && \
    mkdir -p /home/embold/.gems/${RUBY_VERSION} && \
    chown -R embold:embold /home/embold/.gem && \
    su embold -c "gem sources --add https://${GH_USERNAME}:${GH_PACKAGES_TOKEN}@rubygems.pkg.github.com/emboldagency/" && \
    su embold -c "GEM_HOME=/home/embold/.gems/${RUBY_VERSION} gem install colorls --conservative" && \
    su embold -c "GEM_HOME=/home/embold/.gems/${RUBY_VERSION} gem install pulsar-embold --source https://rubygems.pkg.github.com/emboldagency --conservative" && \
    rm -f /home/embold/.gem/credentials && \
    rm -rf /home/embold/.gems/${RUBY_VERSION}/cache

# Copy configuration files
COPY --chmod=775 entrypoint.sh /usr/bin/

USER embold

FROM base AS ruby3.3.4

FROM base AS ruby3.2.5

FROM base AS ruby3.1.6

FROM base AS ruby3.0.7

FROM base AS ruby2.7.8

RUN gem install public_suffix:5.1.1 dotenv:2.8.1 --conservative

FROM ruby${RUBY_VERSION} AS final

# Run before starting to remove server.pid
ENTRYPOINT ["entrypoint.sh"]
