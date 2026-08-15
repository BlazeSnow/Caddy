# 更新日志

## v1.4.3

- 升级基础镜像到 Alpine 3.24
- 新增 Debian slim 基础镜像变体（`<插件>-slim` tag）

## v1.4.2

- 添加了 arm64 的支持

## v1.4.1

- 添加构建前版本检查
- 添加新的 ACME-DNS 提供商：
  - route53
  - duckdns
  - porkbun
  - acmedns
  - digitalocean
  - hetzner
  - ovh
  - desec
  - ionos
  - rfc2136
  - powerdns
  - netcup
  - inwx
  - googleclouddns
  - gandi
  - netlify
  - godaddy

## v1.4.0

- 修改许可证为 MIT

## v1.3.2

- 合并所有 docker tag 到 caddy 主镜像
- 外置 install 和 build 操作

## v1.3.1

- 设置了配置文件和数据文件的存储路径

## v1.3.0

- 添加新的 ACME-DNS 提供商：
  - alidns
  - huaweicloud
  - azure
  - cloudns

## v1.2.0

- 发布了启用 TencentCloud 和 EdgeOne 插件的首个版本

## v1.1.0

- 发布了启用 Webdav 插件的首个版本

## v1.0.0

- 添加 caddy 需求的组件 ca-certificates、libcap 和 mailcap
- 调整权限为 700
- 优化启动命令
- 添加默认 Caddyfile

## 2025-08-06

- 优化构建镜像为 golang
- 优化运行镜像为 alpine

## 2025-07-21

- 首个版本
