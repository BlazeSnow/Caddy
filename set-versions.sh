#!/bin/bash
# set-versions.sh：把本次构建的 Caddy/插件版本和镜像版本 label 写入 GITHUB_ENV
#
# 依赖环境变量：
#   GITHUB_ENV       输出写入目标（GitHub Actions 自动提供）
#   CADDY_VERSION    Caddy 版本号（versions job 输出）
#   PLUGIN_VERSION   插件版本号（matrix）
#   BETA             是否 beta 模式（true/false）
#   GITHUB_REF_TYPE  触发类型（branch/tag）
#   GITHUB_REF_NAME  分支名或 tag 名（GitHub Actions 内置）
set -eu

echo "CADDY_VERSION=$CADDY_VERSION" >>"$GITHUB_ENV"
echo "PLUGIN_VERSION=$PLUGIN_VERSION" >>"$GITHUB_ENV"

if [ "$BETA" = "true" ]; then
	# beta 镜像不携带正式版版本号：tag 触发用 tag 名（如 1.4.4-beta.1），dev 分支为 dev
	if [ "$GITHUB_REF_TYPE" = "tag" ]; then
		APP_VERSION=${GITHUB_REF_NAME#v}
	else
		APP_VERSION="dev"
	fi
else
	APP_VERSION=$(cat VERSION)
fi
echo "APP_VERSION=$APP_VERSION" >>"$GITHUB_ENV"
