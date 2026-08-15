# BlazeSnow/Caddy

![Docker Pulls](https://img.shields.io/docker/pulls/blazesnow/caddy?style=for-the-badge)
![Docker Image Size](https://img.shields.io/docker/image-size/blazesnow/caddy/cloudflare?style=for-the-badge)
![GitHub last commit (branch)](https://img.shields.io/github/last-commit/BlazeSnow/Caddy/main?style=for-the-badge)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/BlazeSnow/Caddy/build.yml?style=for-the-badge)
![GitHub License](https://img.shields.io/github/license/BlazeSnow/Caddy?style=for-the-badge)

镜像名称见：<https://hub.docker.com/r/blazesnow/caddy/tags>

**什么情况需要本镜像？** Caddy 默认通过 HTTP-01 质询验证域名，要求 CA（如 Let's Encrypt）能从公网直接访问你的 80 端口。

- 站点**未套 CDN**（80 端口可直达）：官方 Caddy 镜像即可完成自动 HTTPS，无需使用本镜像
- 站点**套了 CDN**（如腾讯 EdgeOne）：CDN 代理了 80/443 端口，CA 的质询请求穿不透到你的服务器，官方镜像无法完成证书验证。此时应使用本镜像——已集成各主流 DNS 提供商的插件，通过 **DNS-01 质询**（修改 DNS TXT 记录）验证域名，不依赖任何入站端口，选用对应 DNS 提供商的 tag 即可

## 使用

每个插件对应一个独立镜像 tag，以 Cloudflare DNS 插件为例：

**docker run：**

```bash
docker run -d \
  --name caddy \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  -v /path/to/Caddyfile:/etc/caddy/Caddyfile \
  -v caddy_data:/data \
  -v caddy_config:/config \
  blazesnow/caddy:cloudflare
```

**docker compose**（`docker-compose.yml`）：

```yaml
services:
  caddy:
    image: blazesnow/caddy:cloudflare
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
```

在 compose 文件所在目录运行：

```bash
docker compose up -d
```

- 配置目录为 `/config`，数据目录为 `/data`（镜像内通过 `XDG_CONFIG_HOME` / `XDG_DATA_HOME` 指定），建议挂载持久化
- 镜像基于 Alpine，`-alpine` 后缀的 tag 为历史遗留，与不带后缀的内容一致
- 管理端口 2019 可选开放

## ACME-DNS

> 以下内容摘自：<https://caddyserver.com/docs/automatic-https#acme-challenges>
>
> DNS 质询会对候选主机名的 TXT 记录执行权威 DNS 查找，并查找具有特定值的特殊 TXT 记录。如果 CA 发现预期值，则会颁发证书。
>
> 此质询不需要任何开放端口，请求证书的服务器也无需可从外部访问。但是，DNS 质询需要配置。Caddy 需要知道访问您域名的 DNS 提供商的凭据，以便设置（和清除）特殊 TXT 记录。如果启用了 DNS 质询，则默认情况下会禁用其他质询。
>
> 由于 ACME CA 在查找 TXT 记录进行质询验证时遵循 DNS 标准，因此您可以使用 CNAME 记录将质询的应答委托给其他 DNS 区域。这可用于将 _acme-challenge 子域委托给另一个区域。如果您的 DNS 提供商不提供 API，或者 Caddy 的某个 DNS 插件不支持该 API，则此功能尤其有用。

本项目目前支持的提供商，各提供商使用说明见附链接：

| 提供商         | 使用说明                                      |
| -------------- | --------------------------------------------- |
| cloudflare     | <https://github.com/caddy-dns/cloudflare>     |
| tencentcloud   | <https://github.com/caddy-dns/tencentcloud>   |
| edgeone        | <https://github.com/caddy-dns/edgeone>        |
| alidns         | <https://github.com/caddy-dns/alidns>         |
| huaweicloud    | <https://github.com/caddy-dns/huaweicloud>    |
| azure          | <https://github.com/caddy-dns/azure>          |
| cloudns        | <https://github.com/caddy-dns/cloudns>        |
| route53        | <https://github.com/caddy-dns/route53>        |
| duckdns        | <https://github.com/caddy-dns/duckdns>        |
| porkbun        | <https://github.com/caddy-dns/porkbun>        |
| acmedns        | <https://github.com/caddy-dns/acmedns>        |
| digitalocean   | <https://github.com/caddy-dns/digitalocean>   |
| hetzner        | <https://github.com/caddy-dns/hetzner>        |
| ovh            | <https://github.com/caddy-dns/ovh>            |
| desec          | <https://github.com/caddy-dns/desec>          |
| ionos          | <https://github.com/caddy-dns/ionos>          |
| rfc2136        | <https://github.com/caddy-dns/rfc2136>        |
| powerdns       | <https://github.com/caddy-dns/powerdns>       |
| netcup         | <https://github.com/caddy-dns/netcup>         |
| inwx           | <https://github.com/caddy-dns/inwx>           |
| googleclouddns | <https://github.com/caddy-dns/googleclouddns> |
| gandi          | <https://github.com/caddy-dns/gandi>          |
| netlify        | <https://github.com/caddy-dns/netlify>        |
| godaddy        | <https://github.com/caddy-dns/godaddy>        |

## Webdav

使用说明：<https://github.com/mholt/caddy-webdav>

## 许可证

自2025年10月28日起，本软件以MIT的条款发布。

### 第三方组件许可证

本软件中包含的Caddy软件遵守其原有的许可证。
