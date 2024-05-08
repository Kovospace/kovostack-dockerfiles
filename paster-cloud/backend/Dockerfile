FROM openjdk:8-jre-alpine


### set working difectory
#
WORKDIR /app


### copy build java jar
#
COPY build/libs/paster-0.0.1-SNAPSHOT.jar .


### make directories for handling file upload that will be used as volumes later
#
RUN mkdir -p /app/uploads/files
RUN mkdir -p /app/uploads/temp
RUN chmod 755 /app/uploads/files
RUN chmod 755 /app/uploads/temp


### command to run container
#
CMD ["java", "-jar", "paster-0.0.1-SNAPSHOT.jar"]