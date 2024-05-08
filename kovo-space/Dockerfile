# Dockerfile


FROM ruby:2.5.0-alpine


# refresh outdated repos && intall nodejs and npm
#
RUN apk add --no-cache --update-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
    wget libuv nodejs nodejs-npm shared-mime-info sqlite sqlite-dev tzdata build-base libxml2-dev libxslt-dev bash mc


# install required node packages
#
RUN npm install -g yarn


# copy app to working directory
#
RUN mkdir -p /var/app
COPY . /var/app
WORKDIR /var/app


# build rails app
#
RUN bundle install


# precompile assets
#
RUN rake assets:precompile


# run rails app
#
CMD rails s -b 0.0.0.0