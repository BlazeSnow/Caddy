#!/bin/bash
# set-base-digests.sh：查询上游 alpine/debian 基础镜像按架构的 digest，写入 ALPINE/DEBIAN_DIGEST_*
#
# 依赖环境变量：
#   GITHUB_ENV     输出写入目标（GitHub Actions 自动提供）
#   BASE_ALPINE    上游 Alpine 基础镜像 pin（如 public.ecr.aws/docker/library/alpine:3.24）
#   BASE_DEBIAN    上游 Debian 基础镜像 pin
# 前置：buildx 可用。查询失败或结果为空时直接失败，避免 base 镜像带上空的 digest label。
set -eu

base_digest() {
	local ref="$1" arch="$2"
	docker buildx imagetools inspect --raw "$ref" |
		jq -r --arg arch "$arch" '.manifests[] | select(.platform.architecture == $arch) | .digest'
}

ALPINE_DIGEST_AMD64=$(base_digest "$BASE_ALPINE" amd64)
[ -n "$ALPINE_DIGEST_AMD64" ] || {
	echo "获取 alpine(amd64) digest 失败：$BASE_ALPINE" >&2
	exit 1
}
echo "ALPINE_DIGEST_AMD64=$ALPINE_DIGEST_AMD64" >>"$GITHUB_ENV"

ALPINE_DIGEST_ARM64=$(base_digest "$BASE_ALPINE" arm64)
[ -n "$ALPINE_DIGEST_ARM64" ] || {
	echo "获取 alpine(arm64) digest 失败：$BASE_ALPINE" >&2
	exit 1
}
echo "ALPINE_DIGEST_ARM64=$ALPINE_DIGEST_ARM64" >>"$GITHUB_ENV"

DEBIAN_DIGEST_AMD64=$(base_digest "$BASE_DEBIAN" amd64)
[ -n "$DEBIAN_DIGEST_AMD64" ] || {
	echo "获取 debian(amd64) digest 失败：$BASE_DEBIAN" >&2
	exit 1
}
echo "DEBIAN_DIGEST_AMD64=$DEBIAN_DIGEST_AMD64" >>"$GITHUB_ENV"

DEBIAN_DIGEST_ARM64=$(base_digest "$BASE_DEBIAN" arm64)
[ -n "$DEBIAN_DIGEST_ARM64" ] || {
	echo "获取 debian(arm64) digest 失败：$BASE_DEBIAN" >&2
	exit 1
}
echo "DEBIAN_DIGEST_ARM64=$DEBIAN_DIGEST_ARM64" >>"$GITHUB_ENV"
