ARG UBUNTU_VERSION=24.04
ARG RUBY_VERSION=3.4.6
# BASE_IMAGE ARG allows overriding to local tags during development
ARG BASE_IMAGE=ghcr.io/emboldagency/docker-base:ubuntu${UBUNTU_VERSION}

# -----------------------------------------------------------------------------
# Ruby Builder (Compiles source)
# -----------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS ruby_builder

ARG UBUNTU_VERSION
ARG RUBY_VERSION

ENV DEBIAN_FRONTEND=noninteractive

USER root

# Install compilation dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends \
    # Automates script generation for source configuration
    autoconf \
    # Parser generator required for Ruby compilation
    bison \
    # Compilers and tools (gcc, make) to build Ruby
    build-essential \
    # SSL/TLS support for Ruby (OpenSSL)
    libssl-dev \
    # Line editing support for Ruby IRB
    libreadline-dev \
    # Zlib compression support for Ruby
    zlib1g-dev \
    # YAML parsing support for Ruby
    libyaml-dev \
    # FFI support for calling C functions from Ruby
    libffi-dev \
    # GDBM database support for Ruby
    libgdbm-dev \
    # Terminal control support for Ruby
    libncurses-dev \
    # SQLite 3 support for Ruby
    libsqlite3-dev \
    # JPEG image processing headers
    libjpeg-dev \
    # TIFF image processing headers
    libtiff-dev \
    # WebP image processing headers
    libwebp-dev \
    # PostgreSQL client library (for pg gem)
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Compile Ruby
RUN git clone https://github.com/rbenv/ruby-build.git /tmp/ruby-build \
    && PREFIX=/usr/local /tmp/ruby-build/install.sh \
    && /usr/local/bin/ruby-build ${RUBY_VERSION} /usr/local \
    && rm -rf /tmp/ruby-build

# -----------------------------------------------------------------------------
# Gem Builder (Installs generic gems)
# -----------------------------------------------------------------------------
FROM ruby_builder AS ruby_gems
ARG RUBY_VERSION

# Install gems into a system-wide location that we will copy later
ENV GEM_HOME=/coder/gems/ruby/${RUBY_VERSION}
ENV PATH=$GEM_HOME/bin:/usr/local/bin:$PATH

RUN mkdir -p $GEM_HOME \
    && echo 'gem: --no-document' > /etc/gemrc \
    # Ruby 2.7: pin gems whose latest versions dropped 2.7 support
    && if [ "${RUBY_VERSION%.*}" = "2.7" ]; then \
    gem install bundler:2.4.22 public_suffix:5.1.1 dotenv:2.8.1 rake pulsar; \
    else \
    gem install bundler rails rake specific_install; \
    gem specific_install https://github.com/emboldagency/pulsar-embold.git; \
    fi \
    && rm -rf "$GEM_HOME/cache"/*

# -----------------------------------------------------------------------------
# Final Image
# -----------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS final

ARG RUBY_VERSION

# Set up environment variables
ENV LANG=en_US.utf8 \
    TZ=UTC \
    DATE_TIMEZONE=UTC \
    DEBIAN_FRONTEND=noninteractive \
    BUNDLE_APP_CONFIG=/home/embold/.gem/ruby/${RUBY_VERSION} \
    GEM_HOME=/home/embold/.gem/ruby/${RUBY_VERSION} \
    GEM_PATH=/home/embold/.gem/ruby/${RUBY_VERSION}:/coder/gems/ruby/${RUBY_VERSION} \
    # Prepend user gems, then system gems (from /coder/gems)
    PATH=/home/embold/.gem/ruby/${RUBY_VERSION}/bin:/coder/gems/ruby/${RUBY_VERSION}/bin:/usr/local/bin:$PATH \
    PULSAR_CONF_REPO="git@github.com:emboldagency/pulsar.git"

USER root

# Install Runtime Dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends \
    # C++ compiler (sometimes needed for native gem extensions)
    g++ \
    # C compiler for compiling native C extensions
    gcc \
    # Standard C library headers
    libc6-dev \
    # Runtime headers for JPEG support
    libjpeg-dev \
    # Runtime headers for PNG support
    libpng-dev \
    # Runtime headers for PostgreSQL connections
    libpq-dev \
    # Runtime headers for TIFF support
    libtiff-dev \
    # Runtime headers for WebP support
    libwebp-dev \
    # Runtime headers for YAML parsing
    libyaml-dev \
    # Manages library compile/link flags
    pkg-config \
    # CLI tools for interacting with PostgreSQL
    postgresql-client \
    # Runtime headers for compression
    zlib1g-dev \
    # Postgres Repo
    && mkdir -p /usr/share/postgresql-common/pgdg \
    && curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
    && apt-get update \
    && rm -rf /var/lib/apt/lists/*

# Copy Ruby from Builder
COPY --from=ruby_builder /usr/local /usr/local

# Copy Gems from Gem Builder
COPY --chown=embold:embold --from=ruby_gems /coder/gems/ /coder/gems/

USER embold

CMD ["/bin/zsh"]
