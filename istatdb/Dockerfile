# Dockerfile
FROM ruby:2.5

# replace APT files for old Debian release
#
RUN sed -i 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' /etc/apt/sources.list && \
    sed -i 's|http://security.debian.org/debian-security|http://archive.debian.org/debian-security|g' /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "0";' > /etc/apt/apt.conf.d/99no-check-valid-until


# refresh outdated repos && intall nodejs and npm
#
RUN apt-get update && apt-get install -y \
    wget npm shared-mime-info tzdata libxml2-dev libxslt-dev bash mc \
    imagemagick libmagickwand-dev pkg-config


# install required node packages
#
RUN npm install -g yarn


# copy app to working directory
#
RUN mkdir -p /var/app
COPY . /var/app
WORKDIR /var/app
RUN mkdir -p log && touch log/production.log


# Set environment variables
#
ENV RAILS_ENV=production


# Install some gems with native extensions
#
RUN RAILS_ENV=production bundle update caxlsx # mimemagick causing problems with purged version(s) from repo due to licence problems


# build rails app
#
RUN RAILS_ENV=production bundle install


# precompile assets
#
RUN RAILS_ENV=production rake assets:precompile


# run database migrations
#
RUN RAILS_ENV=production rake db:migrate


# run rails app
#
CMD RAILS_ENV=production rails s -b 0.0.0.0
