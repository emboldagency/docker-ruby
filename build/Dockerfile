ARG UBUNTU_VERSION=22.04 \
    RUBY_VERSION=3.0.6

# FROM emboldcreative/base:ubuntu${UBUNTU_VERSION} as base
FROM emboldcreative/base:ubuntu-test

ARG RUBY_VERSION

USER root

COPY --chown=embold:embold --chmod=774 coder /coder

# Install requirements
RUN sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    apt-get update \
    && apt-get install -y -q --no-install-recommends \
    imagemagick \
    libjpeg-dev \
    libpq-dev \
    libtiff-dev \
    libvips \
    libwebp-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/* \
    && ruby-build ${RUBY_VERSION} /usr/local

# Copy configuration files
COPY --chmod=775 entrypoint.sh /usr/bin/

# FROM base as ruby3.0.2

# FROM base as ruby3.0.6

# FROM base as ruby3.1.4

# FROM base as ruby3.2.3

# FROM base as ruby3.3.0

# FROM ruby${RUBY_VERSION} as final

# ARG RUBY_VERSION

USER embold

RUN mkdir -p $GEM_HOME \
    && gem install bundler colorls /coder/pulsar.gem --conservative \
    && bundle update bundler

# Run before starting to remove server.pid
ENTRYPOINT ["entrypoint.sh"]
