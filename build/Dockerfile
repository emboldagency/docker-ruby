FROM registry.embold.app/base:ubuntu20.04

USER root

ENV RUBY_MAJOR=3.0 \
    RUBY_VERSION=3.0.2 \
    RUBY_DOWNLOAD_SHA256=570e7773100f625599575f363831166d91d49a1ab97d3ab6495af44774155c40 \
    # don't create ".bundle" in all our apps
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_APP_CONFIG=$GEM_HOME

# Install requirements
RUN sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && \
    apt-get update &&\
    apt-get install -y -q --no-install-recommends \
    imagemagick \
    libvips \
    libjpeg-dev \
    libtiff-dev \
    libwebp-dev \
    postgresql-client-15 && \
    rm -rf /var/lib/apt/lists/*

# skip installing gem documentation
RUN set -eux; \
    mkdir -p /usr/local/etc; \
    { \
    echo 'install: --no-document'; \
    echo 'update: --no-document'; \
    } >> /usr/local/etc/gemrc; \
    # some of ruby's build scripts are written in ruby
    # we purge system ruby later to make sure our final image uses what we just built
    set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    # bison \
    checkinstall \
    dpkg-dev \
    # libgdbm-dev \
    ruby \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    \
    curl -o ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz"; \
    echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum --check --strict; \
    \
    mkdir -p /usr/src/ruby; \
    tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1; \
    rm ruby.tar.xz; \
    \
    cd /usr/src/ruby; \
    \
    # hack in "ENABLE_PATH_CHECK" disabling to suppress:
    #   warning: Insecure world writable dir
    { \
    echo '#define ENABLE_PATH_CHECK 0'; \
    echo; \
    cat file.c; \
    } > file.c.new; \
    mv file.c.new file.c; \
    autoconf; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    ./configure \
    --build="$gnuArch" \
    --disable-install-doc \
    --enable-shared \
    ; \
    make -j "$(nproc)"; \
    make install; \
    \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark > /dev/null; \
    find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
    | awk '/=>/ { print $(NF-1) }' \
    | sort -u \
    | xargs -r dpkg-query --search \
    | cut -d: -f1 \
    | sort -u \
    | xargs -r apt-mark manual \
    ; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    \
    cd /; \
    rm -r /usr/src/ruby; \
    # verify we have no "ruby" packages installed
    ! dpkg -l | grep -i ruby; \
    [ "$(command -v ruby)" = '/usr/local/bin/ruby' ]; \
    # rough smoke test
    ruby --version; \
    gem --version; \
    bundle --version

# Ruby gems
RUN mkdir -p $GEM_HOME && \
    gem install bundler colorls /coder/pulsar.gem && \
    chown -R embold:embold $GEM_HOME && \
    chmod -R 1777 $GEM_HOME

# Copy configuration files
COPY entrypoint.sh /usr/bin/

RUN chmod +x /coder/configure && \
    chmod +x /usr/bin/entrypoint.sh

USER embold

# Run before starting to remove server.pid
ENTRYPOINT ["entrypoint.sh"]