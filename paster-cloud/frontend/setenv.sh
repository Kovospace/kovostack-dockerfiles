#!/bin/bash

ASSETS_FOLDER="${ASSETS_FOLDER:-./src/assets/}"
STATIC_INDEX_FILE="${STATIC_INDEX_FILE-./src/index.html}"
JS_FILENAME="env.js"
ENV_VARS=$(/bin/sh -c /usr/bin/env)

### Create JSON object with JSON-ized ENV variables
#
OUTPUT_JSON="const envData={"
line_counter=0
for env_var in $ENV_VARS; do
  IFS='=' read -r key val <<< "$env_var"
  if [ $line_counter -eq 0 ]; then
    OUTPUT_JSON+="\"$key\":\"$val\""
  else
    OUTPUT_JSON+=",\"$key\":\"$val\""
  fi
  ((line_counter++))
done
OUTPUT_JSON+="};"

### Create script that will pass this object into "widnow" object
#   This script will be loaded on app (or container) start
#
OUTPUT_JS_SOURCE="
(function(window) {
  window.env = window.env || envData;
})(this);"

### create file in static assets folder of Angular app and append content here
#
echo "$OUTPUT_JSON" > "$ASSETS_FOLDER$JS_FILENAME"
echo "$OUTPUT_JS_SOURCE" >> "$ASSETS_FOLDER$JS_FILENAME"

### Inject JS file href into static HTML <head>
#
#   Run this script on application start
#   or insert it into Dockerfile of app and run it using CMD
#   env variables will be available at runtime bounded to "window.env" object
#
#   example:
#
#   Dockerfile (if creating docker image):
#     COPY setenv.sh ./
#     RUN chmod +x setenv.sh
#     CMD ["/bin/sh", "-c", "setenv.sh"]
#
#   docker-compose or simply ENV variable defined on target environment:
#     MY_ENV_VAR=someValue
#
#   runtime of Angular app:
#     const myEnvVar = window.env.MY_ENV_VAR;
#
if awk '/<head>/ {in_head=1} /<\/head>/ {in_head=0} in_head && /<script src="assets\/env.js"> <\/script>/ {found=1} END {exit !found}' "$STATIC_INDEX_FILE"; then
  echo "Script tag already exists in the <head>."
else
  # Inject the <script> tag into the <head> section
  awk '/<\/head>/ && !injected {print "<script src=\"assets/env.js\"> </script>"; injected=1} 1' "$STATIC_INDEX_FILE" > temp.html && mv temp.html "$STATIC_INDEX_FILE"
  echo "Script tag injected into the <head>."
fi
