FROM golang:1.27-alpine AS build

WORKDIR /src
COPY app/ .
RUN CGO_ENABLED=0 go build -o /server ./cmd/server

FROM alpine:3.23

RUN apk upgrade --no-cache \
    && apk add --no-cache ca-certificates \
    && addgroup -S -g 101 app \
    && adduser -S -D -H -u 100 -G app app

COPY --from=build --chown=100:101 /server /server

USER 100:101
EXPOSE 8080
ENTRYPOINT ["/server"]
