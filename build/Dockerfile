ARG UBUNTU_VERSION=22.04 \
    RUBY_VERSION=3.0.6

# FROM emboldcreative/base:ubuntu${UBUNTU_VERSION}
FROM emboldcreative/base:ubuntu-test

ARG RUBY_VERSION

USER root

COPY --chown=embold:embold --chmod=774 coder /coder

# Install requirements
RUN sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && \
    apt-get update &&\
    apt-get install -y -q --no-install-recommends \
    imagemagick \
    libjpeg-dev \
    libpq-dev \
    libtiff-dev \
    libvips \
    libwebp-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files
COPY --chmod=775 entrypoint.sh /usr/bin/

USER embold

RUN rbenv install --skip-existing $RUBY_VERSION \
    && rbenv global $RUBY_VERSION \
    && rbenv rehash \
    && gem install bundler colorls /coder/pulsar.gem --conservative

# Run before starting to remove server.pid
ENTRYPOINT ["entrypoint.sh"]
