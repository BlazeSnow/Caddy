#!/bin/bash
# check-base.sh：判断静态基础镜像是否需要重建，输出 needed=true/false
#
# 依赖环境变量：
#   GITHUB_OUTPUT       输出写入目标（GitHub Actions 自动提供）
#   BASE_CHANGED        上游基础镜像 digest 是否变化（versions job 输出）
#   FORCE_BUILD         强制构建（true/false）
#   BASE_IMAGE_REPO     基础镜像仓库（ghcr.io/blazesnow/caddy-base）
#   BASE_TAG_ALPINE     Alpine 基础镜像 tag
#   BASE_TAG_DEBIAN     Debian 基础镜像 tag
#   BASE_TAG_SUFFIX     beta 后缀（dev 分支为 -beta，其余为空）
set -eu

NEED="false"
if [ "${BASE_CHANGED:-}" = "true" ] || [ "${FORCE_BUILD:-}" = "true" ]; then
	NEED="true"
else
	for TAG in \
		"${BASE_IMAGE_REPO}:${BASE_TAG_ALPINE}${BASE_TAG_SUFFIX}" \
		"${BASE_IMAGE_REPO}:${BASE_TAG_DEBIAN}${BASE_TAG_SUFFIX}"; do
		if ! docker manifest inspect "$TAG" >/dev/null 2>&1; then
			NEED="true"
			break
		fi
	done
fi
echo "needed=$NEED" >>"$GITHUB_OUTPUT"
echo "需要重建基础镜像：$NEED"
