FROM emboldcreative/base:latest

USER root

# Postgres installation
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
RUN apt-get update && apt-get install -y postgresql-12 postgresql-server-dev-12

# Begin From docker-library ruby 2.6 image

# skip installing gem documentation
RUN set -eux; \
  mkdir -p /usr/local/etc; \
  { \
  echo 'install: --no-document'; \
  echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc

ENV LANG C.UTF-8
ENV RUBY_MAJOR 2.6
ENV RUBY_VERSION 2.6.9
ENV RUBY_DOWNLOAD_SHA256 6a041d82ae6e0f02ccb1465e620d94a7196489d8a13d6018a160da42ebc1eece

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -eux; \
  \
  savedAptMark="$(apt-mark showmanual)"; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  bison \
  dpkg-dev \
  libgdbm-dev \
  ruby \
  ; \
  rm -rf /var/lib/apt/lists/*; \
  \
  wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz"; \
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
  \
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

# don't create ".bundle" in all our apps
ARG GEM_HOME=/home/embold/gems
ENV GEM_HOME=$GEM_HOME
ENV BUNDLE_SILENCE_ROOT_WARNING=1 \
  BUNDLE_APP_CONFIG=$GEM_HOME
ENV PATH $GEM_HOME/bin:$PATH
# adjust permissions of a few directories for running "gem install" as an arbitrary user
RUN mkdir -p $GEM_HOME
RUN chmod -R 777 $GEM_HOME
RUN chown -R embold:embold $GEM_HOME

# End From docker-library ruby 2.6 image

RUN gem install bundler

RUN chown -R embold:embold $GEM_HOME
RUN chown -R embold:embold /usr/local/lib/ruby
RUN chmod u+s /usr/local/lib/ruby
RUN chmod u+s $GEM_HOME

COPY [ "configure", "/coder/configure" ]

RUN chmod +x /coder/configure

# Install Solidus requirement
RUN apt-get update

# Install Solidus requirement
RUN apt-get install -y imagemagick

# Install Solidus requirement (replacing imagemagick, but we'll do both for now to support both deployments)
RUN apt-get install -y libvips

# Install webp conversion requirements
RUN apt-get install -y libjpeg-dev libpng-dev libtiff-dev libwebp-dev

USER embold

WORKDIR /code

# Run before starting to remove server.pid
COPY entrypoint.sh /usr/bin/
RUN sudo chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
