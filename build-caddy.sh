#!/bin/bash
# build-caddy.sh：用 xcaddy 编译 linux/amd64 和 linux/arm64 两个架构的 Caddy 二进制
#
# 依赖环境变量：CADDY_VERSION、PLUGIN（模块路径）、PLUGIN_VERSION
set -eu

mkdir -p dist/linux_amd64 dist/linux_arm64

for arch in amd64 arm64; do
  echo "构建 Caddy ${CADDY_VERSION} + ${PLUGIN}@${PLUGIN_VERSION} for linux/${arch}"
  CGO_ENABLED=0 GOOS=linux GOARCH=${arch} xcaddy build "${CADDY_VERSION}" \
    --with "${PLUGIN}@${PLUGIN_VERSION}" \
    --output "dist/linux_${arch}/caddy"
  chmod +x "dist/linux_${arch}/caddy"
done
