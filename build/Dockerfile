ARG RUBY_VERSION=3.0.6

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

RUN RUBY_VERSION=${RUBY_VERSION} /coder/scripts/ruby-install.sh

# Run before starting to remove server.pid
ENTRYPOINT ["entrypoint.sh"]
