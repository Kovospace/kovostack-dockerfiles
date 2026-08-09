FROM ruby:2.5.0-alpine

# Ruby 2.5.0-alpine is based on an old Alpine release.
# Do NOT use Alpine Edge here — it gives us incompatible modern Node/npm
# packages for this legacy Rails application.

RUN apk add --no-cache \
    --repository http://dl-cdn.alpinelinux.org/alpine/v3.7/main \
    nodejs \
    nodejs-npm \
    libuv \
    shared-mime-info \
    sqlite \
    sqlite-dev \
    tzdata \
    build-base \
    libxml2-dev \
    libxslt-dev \
    bash \
    wget

# Legacy Rails 4.2 application -> Yarn 1
RUN npm install -g yarn@1.22.22

# Copy application
RUN mkdir -p /var/app
COPY . /var/app
WORKDIR /var/app

# Install Ruby dependencies
RUN bundle install

ENV RAILS_ENV=production

# Compile Rails assets into the image.
#
# The pod mounts the real sqlite database from a PVC, so it does not exist at
# build time -- but precompiling boots the application, and both Devise and the
# route constraints in lib/constraints hit the database while booting. Load
# db/schema.rb into a throwaway database first (plain ActiveRecord, no Rails
# boot) and point the precompile at it.
RUN bundle exec ruby -e "\
      require 'active_record'; \
      ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: '/tmp/build.sqlite3'); \
      ActiveRecord::Migration.verbose = false; \
      load 'db/schema.rb'" \
    && DATABASE_URL=sqlite3:///tmp/build.sqlite3 DISABLE_SPRING=1 \
       bundle exec rake assets:precompile \
    && rm -f /tmp/build.sqlite3 \
    && rm -rf tmp/cache

# Run Rails
CMD ["rails", "s", "-b", "0.0.0.0"]