FROM golang:alpine AS builder

RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

WORKDIR /build

RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM alpine:latest

RUN apk add --no-cache ca-certificates libcap mailcap

COPY --from=builder /build/caddy /usr/bin/caddy

RUN chmod 700 /usr/bin/caddy

COPY ./Caddyfile /etc/caddy/Caddyfile

EXPOSE 80 443 443/udp 2019

CMD ["/usr/bin/caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
