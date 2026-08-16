#!/bin/bash
# set-base-digests.sh：查询基础镜像的 index digest，写入 BASE_DIGEST_ALPINE / BASE_DIGEST_DEBIAN
#
# 依赖环境变量：
#   GITHUB_ENV        输出写入目标（GitHub Actions 自动提供）
#   BASE_IMAGE_REPO   基础镜像仓库（ghcr.io/blazesnow/caddy-base）
#   BASE_TAG_ALPINE   Alpine 基础镜像 tag
#   BASE_TAG_DEBIAN   Debian 基础镜像 tag
#   BASE_TAG_SUFFIX   beta 后缀
# 前置：已登录 GHCR（docker/login-action），buildx 可用。
# 查询失败或结果为空时直接失败，避免镜像带上空的 base.digest label。
set -eu

base_digest() {
	local ref="$1"
	docker buildx imagetools inspect "$ref" | sed -n 's/^Digest:[[:space:]]*//p' | head -1
}

ALPINE=$(base_digest "${BASE_IMAGE_REPO}:${BASE_TAG_ALPINE}${BASE_TAG_SUFFIX}")
[ -n "$ALPINE" ] || {
	echo "获取 Alpine base digest 失败" >&2
	exit 1
}
echo "BASE_DIGEST_ALPINE=$ALPINE" >>"$GITHUB_ENV"

DEBIAN=$(base_digest "${BASE_IMAGE_REPO}:${BASE_TAG_DEBIAN}${BASE_TAG_SUFFIX}")
[ -n "$DEBIAN" ] || {
	echo "获取 Debian base digest 失败" >&2
	exit 1
}
echo "BASE_DIGEST_DEBIAN=$DEBIAN" >>"$GITHUB_ENV"
