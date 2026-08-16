# 更新日志

## v1.4.4

1. 构建优化：静态层（依赖、默认配置、环境变量）拆分为独立基础镜像 `ghcr.io/blazesnow/caddy-base`，插件镜像只注入对应架构的二进制，重建时不再重复安装依赖
2. 构建优化：Go 编译缓存跨插件共享，Caddy 版本升级等全量重建场景下各插件只编译自身的代码，其余复用核心编译产物，构建时间大幅缩短
3. 构建优化：插件镜像构建不再需要 QEMU 模拟执行
4. 重构：基础镜像重建判断（`check-base.sh`）与 README 同步（`sync-readme.sh`）从工作流内联脚本拆分为仓库根目录独立脚本，全部脚本统一经 shfmt 格式化

## v1.4.3

1. 升级基础镜像到 Alpine 3.24
2. 新增 Debian slim 基础镜像变体（`<插件>-slim` tag）

## v1.4.2

1. 添加了 arm64 的支持

## v1.4.1

1. 添加构建前版本检查
2. 添加新的 ACME-DNS 提供商：
   1. route53
   2. duckdns
   3. porkbun
   4. acmedns
   5. digitalocean
   6. hetzner
   7. ovh
   8. desec
   9. ionos
   10. rfc2136
   11. powerdns
   12. netcup
   13. inwx
   14. googleclouddns
   15. gandi
   16. netlify
   17. godaddy

## v1.4.0

1. 修改许可证为 MIT

## v1.3.2

1. 合并所有 docker tag 到 caddy 主镜像
2. 外置 install 和 build 操作

## v1.3.1

1. 设置了配置文件和数据文件的存储路径

## v1.3.0

1. 添加新的 ACME-DNS 提供商：
   1. alidns
   2. huaweicloud
   3. azure
   4. cloudns

## v1.2.0

1. 发布了启用 TencentCloud 和 EdgeOne 插件的首个版本

## v1.1.0

1. 发布了启用 Webdav 插件的首个版本

## v1.0.0

1. 添加 caddy 需求的组件 ca-certificates、libcap 和 mailcap
2. 调整权限为 700
3. 优化启动命令
4. 添加默认 Caddyfile

## 2025-08-06

1. 优化构建镜像为 golang
2. 优化运行镜像为 alpine

## 2025-07-21

1. 首个版本
