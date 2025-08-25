# BlazeSnow/Caddy

<https://hub.docker.com/r/blazesnow/caddy>

## ACME-DNS

> 以下内容摘自：<https://caddyserver.com/docs/automatic-https#acme-challenges>
>
> DNS 质询会对候选主机名的 TXT 记录执行权威 DNS 查找，并查找具有特定值的特殊 TXT 记录。如果 CA 发现预期值，则会颁发证书。
>
> 此质询不需要任何开放端口，请求证书的服务器也无需可从外部访问。但是，DNS 质询需要配置。Caddy 需要知道访问您域名的 DNS 提供商的凭据，以便设置（和清除）特殊 TXT 记录。如果启用了 DNS 质询，则默认情况下会禁用其他质询。
>
> 由于 ACME CA 在查找 TXT 记录进行质询验证时遵循 DNS 标准，因此您可以使用 CNAME 记录将质询的应答委托给其他 DNS 区域。这可用于将 _acme-challenge 子域委托给另一个区域。如果您的 DNS 提供商不提供 API，或者 Caddy 的某个 DNS 插件不支持该 API，则此功能尤其有用。

本项目目前支持的提供商：

- Cloudflare
- TencentCloud

### Cloudflare

> 启用Caddy的DNS质询提供商Cloudflare：<https://github.com/caddy-dns/cloudflare>

```shell
docker pull blazesnow/caddy:cloudflare-alpine
```

1. API设置页面：<https://dash.cloudflare.com/profile/api-tokens>
2. API权限需要设置`Zone.Zone:Read`和`Zone.DNS:Edit`
3. Caddyfile示例如下：

```Caddyfile
example.com {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
    }
}
```

### TencentCloud

> 启用Caddy的DNS质询提供商TencentCloud（DNSPod）：<https://github.com/caddy-dns/tencentcloud>

```shell
docker pull blazesnow/caddy:tencentcloud-alpine
```

1. API设置页面：<https://console.dnspod.cn/account/token/apikey>
2. Caddyfile示例如下：

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

## Webdav

> 启用Caddy的WebDAV插件

```shell
docker pull blazesnow/caddy:webdav-alpine
```

使用说明：<https://github.com/mholt/caddy-webdav>
