# 更新日志

## v1.4.4

- 构建优化：静态层（依赖、默认配置、环境变量）拆分为独立基础镜像 `ghcr.io/blazesnow/caddy-base`，插件镜像只注入对应架构的二进制，重建时不再重复安装依赖
- 构建优化：Go 编译缓存跨插件共享，Caddy 版本升级等全量重建场景下各插件只编译自身的代码，其余复用核心编译产物，构建时间大幅缩短
- 构建优化：插件镜像构建不再需要 QEMU 模拟执行
- 重构：基础镜像重建判断（`check-base.sh`）与 README 同步（`sync-readme.sh`）从工作流内联脚本拆分为仓库根目录独立脚本，全部脚本统一经 shfmt 格式化

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
