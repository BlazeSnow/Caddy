# [Blazesnow/Caddy](https://hub.docker.com/r/blazesnow/caddy)

![Docker Pulls](https://img.shields.io/docker/pulls/blazesnow/caddy)

Language/语言：

- [English](/README.md)
- [简体中文](/README.zh-CN.md)

## ACME-DNS

> The following is an excerpt from: <https://caddyserver.com/docs/automatic-https#acme-challenges>
>
> The DNS challenge performs an authoritative DNS lookup for the candidate hostname's TXT records, and looks for a special TXT record with a certain value. If the CA sees the expected value, a certificate is issued.
>
> This challenge does not require any open ports, and the server requesting a certificate does not need to be externally accessible. However, the DNS challenge requires configuration. Caddy needs to know the credentials to access your domain's DNS provider so it can set (and clear) the special TXT records. If the DNS challenge is enabled, other challenges are disabled by default.
>
> Since ACME CAs follow DNS standards when looking up TXT records for challenge verification, you can use CNAME records to delegate answering the challenge to other DNS zones. This can be used to delegate the _acme-challenge subdomain to another zone. This is particularly useful if your DNS provider doesn't provide an API, or isn't supported by one of the DNS plugins for Caddy.

Providers currently supported by this project:

- Cloudflare
- TencentCloud

### Cloudflare

![Docker Image Size (tag)](https://img.shields.io/docker/image-size/blazesnow/caddy/cloudflare-alpine)

> Enables the Cloudflare DNS challenge provider for Caddy: <https://github.com/caddy-dns/cloudflare>

```shell
docker pull blazesnow/caddy:cloudflare-alpine
```

1. API settings page: <https://dash.cloudflare.com/profile/api-tokens>
2. API permissions need to be set to `Zone.Zone:Read` and `Zone.DNS:Edit`.
3. Example Caddyfile:

```Caddyfile
example.com {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
    }
}
```

### TencentCloud

![Docker Image Size (tag)](https://img.shields.io/docker/image-size/blazesnow/caddy/tencentcloud-alpine)

> Enables the TencentCloud (DNSPod) DNS challenge provider for Caddy: <https://github.com/caddy-dns/tencentcloud>

```shell
docker pull blazesnow/caddy:tencentcloud-alpine
```

1. API settings page: <https://console.cloud.tencent.com/cam/capi>
2. Example Caddyfile:

```Caddyfile
example.com {
    tls {
        dns tencentcloud {
            secret_id {env.TENCENTCLOUD_SECRET_ID}
            secret_key {env.TENCENTCLOUD_SECRET_KEY}
        }
    }
}
```

### EdgeOne

![Docker Image Size (tag)](https://img.shields.io/docker/image-size/blazesnow/caddy/edgeone-alpine)

> Enables the EdgeOne DNS challenge provider for Caddy: <https://github.com/caddy-dns/edgeone>

```shell
docker pull blazesnow/caddy:edgeone-alpine
```

1. API settings page: <https://console.cloud.tencent.com/cam/capi>
2. Example Caddyfile:

```Caddyfile
example.com {
    tls {
        dns edgeone {
            secret_id {env.TENCENTCLOUD_SECRET_ID}
            secret_key {env.TENCENTCLOUD_SECRET_KEY}
        }
    }
}
```

## Webdav

![Docker Image Size (tag)](https://img.shields.io/docker/image-size/blazesnow/caddy/webdav-alpine)

> Enables the WebDAV plugin for Caddy

```shell
docker pull blazesnow/caddy:webdav-alpine
```

Usage instructions: <https://github.com/mholt/caddy-webdav>
