# Use an official Node.js runtime as a parent image
# This image is just temporary for 1st stage to build the angular app
FROM node:19-alpine as build-temp

# install needed linux packages
RUN apk add --no-cache bash

# Set the working directory to /app
WORKDIR /app

# Copy package.json and package-lock.json to /app
COPY package*.json .

# Copy script that will organize propagation of ENV variables into angular app runtime
COPY setenv.sh .
RUN chmod +x setenv.sh

# Install app dependencies
RUN npm install

# Copy app source code to /app
COPY . .

# Run script that will bind container ENV variables into Angular runtime
RUN /bin/bash setenv.sh

# Build the app for production
RUN npm run build --prod



# Install NGINX that will serve built application (static files)
FROM nginx:alpine

# install needed linux packages
RUN apk add --no-cache bash

# copy static assets into NGINX html folder
COPY --from=build-temp /app/dist/PasterFrontend /usr/share/nginx/html

# copy NGINX config
COPY ./nginx.conf /etc/nginx/nginx.conf

# copy and run utility fo passing ENV vars into angular app runtime
COPY setenv.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.d/setenv.sh

# Open port for application
EXPOSE 4204

# run NGINX and env vars assignment
# following ENV vars are used by utility enabling them to angular app runtime
ENV ASSETS_FOLDER=/usr/share/nginx/html/assets/
ENV STATIC_INDEX_FILE=/usr/share/nginx/html/index.html

CMD ["nginx", "-g", "daemon off;"]
