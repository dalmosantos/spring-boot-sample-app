FROM nexus.verity.local:18443/centos-oracle-java8

MAINTAINER devsecops@verity.com.br

RUN mkdir -p /opt/pause

COPY ./src/pause-web/target/pause-web.war /opt/pause/pause-web.war
COPY ./src/pause-web/src/main/resources/application.properties /opt/pause/application.properties

RUN echo ola
ENTRYPOINT [ "sh", "-c", "java -jar /opt/pause/pause-web.war --spring.config.location=file:/opt/pause/application.properties" ]
