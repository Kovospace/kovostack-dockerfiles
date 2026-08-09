### ---------- build stage ----------
#
# JDK 11 is used to *run* Gradle (the openapi-generator plugin needs 11+),
# build.gradle still targets Java 8 bytecode, so the artifact runs on a JRE 8.
FROM eclipse-temurin:11-jdk AS build

WORKDIR /src


### gradle wrapper + build scripts first, so the dependency download
### layer is cached and only invalidated when the build config changes
#
COPY gradlew ./
COPY gradle ./gradle
COPY build.gradle settings.gradle ./

### NOTE: gradlew is invoked as `sh gradlew` (not `./gradlew`) because the
### wrapper's shebang is broken (`#!/usr/bin/env.sh sh`); scripts/*.sh do the same.
#
RUN sh gradlew --no-daemon dependencies > /dev/null 2>&1 || true


### application sources
#
COPY src ./src


### build the executable (fat) jar; tests run in the CI workflow, not here
#
RUN sh gradlew --no-daemon clean bootJar -x test \
 && cp build/libs/paster-*-SNAPSHOT.jar /app.jar



### ---------- runtime stage ----------
#
FROM eclipse-temurin:8-jre-alpine


### set working directory
#
WORKDIR /app


### copy built java jar
#
COPY --from=build /app.jar ./paster.jar


### make directories for handling file upload that will be used as volumes later
#
RUN mkdir -p /app/uploads/files /app/uploads/temp \
 && chmod 755 /app/uploads/files /app/uploads/temp


### command to run container
#
CMD ["java", "-jar", "paster.jar"]