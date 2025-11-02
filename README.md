# BlazeSnow/Caddy

![Docker Pulls](https://img.shields.io/docker/pulls/blazesnow/caddy?style=for-the-badge)
![Docker Image Size](https://img.shields.io/docker/image-size/blazesnow/caddy?style=for-the-badge)
![GitHub last commit (branch)](https://img.shields.io/github/last-commit/BlazeSnow/Caddy/main?style=for-the-badge)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/BlazeSnow/Caddy/publish.yml?style=for-the-badge)
![GitHub License](https://img.shields.io/github/license/BlazeSnow/Caddy?style=for-the-badge)

镜像名称见：<https://hub.docker.com/r/blazesnow/caddy/tags>

## ACME-DNS

> 以下内容摘自：<https://caddyserver.com/docs/automatic-https#acme-challenges>
>
> DNS 质询会对候选主机名的 TXT 记录执行权威 DNS 查找，并查找具有特定值的特殊 TXT 记录。如果 CA 发现预期值，则会颁发证书。
>
> 此质询不需要任何开放端口，请求证书的服务器也无需可从外部访问。但是，DNS 质询需要配置。Caddy 需要知道访问您域名的 DNS 提供商的凭据，以便设置（和清除）特殊 TXT 记录。如果启用了 DNS 质询，则默认情况下会禁用其他质询。
>
> 由于 ACME CA 在查找 TXT 记录进行质询验证时遵循 DNS 标准，因此您可以使用 CNAME 记录将质询的应答委托给其他 DNS 区域。这可用于将 _acme-challenge 子域委托给另一个区域。如果您的 DNS 提供商不提供 API，或者 Caddy 的某个 DNS 插件不支持该 API，则此功能尤其有用。

本项目目前支持的提供商，各提供商使用说明见附链接：

| 提供商       | 使用说明                                    |
| ------------ | ------------------------------------------- |
| cloudflare   | <https://github.com/caddy-dns/cloudflare>   |
| tencentcloud | <https://github.com/caddy-dns/tencentcloud> |
| edgeone      | <https://github.com/caddy-dns/edgeone>      |
| alidns       | <https://github.com/caddy-dns/alidns>       |
| huaweicloud  | <https://github.com/caddy-dns/huaweicloud>  |
| azure        | <https://github.com/caddy-dns/azure>        |
| cloudns      | <https://github.com/caddy-dns/cloudns>      |

## Webdav

使用说明：<https://github.com/mholt/caddy-webdav>

## 许可证

自2025年10月28日起，本软件以MIT的条款发布。

### 第三方组件许可证

本软件中包含的Caddy软件遵守其原有的许可证。
