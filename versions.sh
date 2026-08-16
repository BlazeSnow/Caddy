#!/bin/bash
# versions.sh：查询插件版本，结合构建清单判断哪些插件需要构建，输出 matrix / all_versions / base_changed
#
# 依赖环境变量：
#   GITHUB_OUTPUT   输出写入目标（GitHub Actions 自动提供）
#   GITHUB_REF      当前分支或 tag（refs/heads/dev 或 v*-beta* tag 时为 beta 模式）
#   FORCE_BUILD     强制全量构建（true/false）
#   BASE_ALPINE     Alpine 基础镜像 pin
#   BASE_DEBIAN     Debian 基础镜像 pin
#   BETA_PLUGINS    beta 模式只考虑这些插件
set -eu

jq -e 'type == "array" and length > 0' plugins.json >/dev/null || {
	echo "::error::plugins.json 无效或为空"
	exit 1
}

FORCE="false"
if [ "${FORCE_BUILD:-}" = "true" ]; then
	FORCE="true"
fi
# 推送 tag（发布 beta/稳定版）视为强制构建：忽略跳过逻辑，全部插件重建
if [[ "$GITHUB_REF" == refs/tags/* ]]; then
	FORCE="true"
fi

MANIFEST="{}"
if [ -f .build-cache/manifest.json ]; then
	MANIFEST=$(cat .build-cache/manifest.json)
fi

# 获取基础镜像指纹（该 tag 下所有平台的 digest 排序）。
# curl 失败（限流/网络）或响应为空时返回 "unknown"。注意不能用管道退出码判断——
# 空输入时 jq 会输出 [] 且退出码为 0，因此先抓原始响应再解析。
base_fingerprint() {
	local url="$1" raw fp
	raw=$(curl -sf "$url") || {
		echo "unknown"
		return
	}
	[ -n "$raw" ] || {
		echo "unknown"
		return
	}
	fp=$(printf '%s' "$raw" | jq -c '[.images[].digest] | sort') || {
		echo "unknown"
		return
	}
	echo "$fp"
}
ALPINE_FP=$(base_fingerprint "https://hub.docker.com/v2/repositories/library/alpine/tags/${BASE_ALPINE##*:}")
DEBIAN_FP=$(base_fingerprint "https://hub.docker.com/v2/repositories/library/debian/tags/${BASE_DEBIAN##*:}")

# manifest 缺失时（如 tag 触发的运行访问不到 dev 分支缓存）不强制重建，
# 基础镜像是否缺失由 check-base.sh 的 manifest inspect 兜底
BASE_CHANGED="false"
if [ "$(printf '%s' "$MANIFEST" | jq -r 'has("base_alpine") and has("base_debian")')" = "true" ] &&
	[ "$ALPINE_FP" != "unknown" ] && [ "$DEBIAN_FP" != "unknown" ]; then
	if [ "$(printf '%s' "$MANIFEST" | jq -r '.base_alpine')" != "$ALPINE_FP" ] ||
		[ "$(printf '%s' "$MANIFEST" | jq -r '.base_debian')" != "$DEBIAN_FP" ]; then
		BASE_CHANGED="true"
	fi
fi

BETA_MODE="false"
if [ "$GITHUB_REF" = "refs/heads/dev" ] || [[ "$GITHUB_REF" == refs/tags/*-beta* ]]; then
	BETA_MODE="true"
	echo "beta 模式：仅考虑 $BETA_PLUGINS"
fi

if [ "$BETA_MODE" = "true" ]; then
	SELECTED=$(jq -c --arg list "$BETA_PLUGINS" '[.[] | select(. as $p | ($list | split(" ") | index($p.name)) != null)] | .[]' plugins.json)
else
	SELECTED=$(jq -c '.[]' plugins.json)
fi

MATRIX='[]'
ALL='{}'
while IFS= read -r entry; do
	name=$(jq -r '.name' <<<"$entry")
	context=$(jq -r '.context' <<<"$entry")
	plugin_version=$(go list -m -json "${context}@latest" | jq -r '.Version')

	ALL=$(printf '%s' "$ALL" | jq -c --arg name "$name" --arg plugin_version "$plugin_version" \
		'. + {($name): $plugin_version}')

	last_built=$(printf '%s' "$MANIFEST" | jq -r --arg name "$name" '.[$name] // "none"')
	if [ "$FORCE" = "true" ] || [ "$BASE_CHANGED" = "true" ] || [ "$last_built" != "$plugin_version" ]; then
		MATRIX=$(printf '%s' "$MATRIX" | jq -c \
			--arg name "$name" --arg context "$context" --arg plugin_version "$plugin_version" \
			'. + [{name: $name, context: $context, plugin_version: $plugin_version}]')
	fi
done <<<"$SELECTED"

ALL=$(printf '%s' "$ALL" | jq -c --arg base_alpine "$ALPINE_FP" --arg base_debian "$DEBIAN_FP" \
	'. + {base_alpine: $base_alpine, base_debian: $base_debian}')

echo "matrix=$MATRIX" >>"$GITHUB_OUTPUT"
echo "all_versions=$ALL" >>"$GITHUB_OUTPUT"
echo "base_changed=$BASE_CHANGED" >>"$GITHUB_OUTPUT"
