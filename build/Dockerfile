ARG UBUNTU_VERSION=22.04 \
    RUBY_VERSION=3.0.2

FROM emboldcreative/base:ubuntu${UBUNTU_VERSION} as base

ARG RUBY_VERSION

ENV BUNDLE_APP_CONFIG=/home/embold/.gems/${RUBY_VERSION} \
    GEM_HOME=/home/embold/.gems/${RUBY_VERSION} \
    PATH=$PATH:/home/embold/.gems/${RUBY_VERSION}/bin

USER root

COPY --chown=embold:embold --chmod=774 coder /coder

# Install requirements
RUN install -d /usr/share/postgresql-common/pgdg \
    && curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
    && apt-get update \
    && apt-get install -y -q --no-install-recommends \
    imagemagick \
    libjpeg-dev \
    libpq-dev \
    libtiff-dev \
    libvips \
    libwebp-dev \
    postgresql-client \
    tzdata \
    && rm -rf /var/lib/apt/lists/* \
    # Combine our configure scripts
    && cd /coder \
    && cat scripts/configure-ruby >> scripts/configure \
    && ruby-build ${RUBY_VERSION} /usr/local \
    && gem update --system \
    && chown -R embold:embold /home/embold/.gems

# Copy configuration files
COPY --chmod=775 entrypoint.sh /usr/bin/

USER embold

RUN mkdir -p $GEM_HOME \
    && gem install colorls /coder/pulsar-*.gem --conservative

# Run before starting to remove server.pid
ENTRYPOINT ["entrypoint.sh"]
