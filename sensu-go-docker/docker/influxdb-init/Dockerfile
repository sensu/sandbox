FROM alpine:latest
RUN apk add -U --no-cache curl
ENV DOCKERIZE_VERSION v0.6.1
RUN curl https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz -Lso dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

CMD dockerize -wait tcp://influxdb:8086 -timeout 30s curl -i -XPOST http://influxdb:8086/query --data-urlencode "q=CREATE DATABASE sensu"
