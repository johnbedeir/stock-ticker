FROM golang:1.23-alpine AS build

RUN apk add --no-cache ca-certificates

WORKDIR /src
COPY app/go.mod app/go.sum* ./
RUN go mod download

COPY app/ .
RUN CGO_ENABLED=0 go build -o /server ./cmd/server

FROM alpine:3.20

RUN apk add --no-cache ca-certificates \
    && addgroup -S app \
    && adduser -S -G app app

WORKDIR /home/app
COPY --from=build /server /home/app/server

USER app
EXPOSE 8080
ENTRYPOINT ["/home/app/server"]
