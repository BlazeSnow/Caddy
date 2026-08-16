#!/bin/bash
# versions.sh：查询插件版本，结合构建清单判断哪些插件需要构建，输出 matrix / all_versions / base_changed
#
# 依赖环境变量：
#   GITHUB_OUTPUT   输出写入目标（GitHub Actions 自动提供）
#   GITHUB_REF      当前分支（refs/heads/dev 时为 beta 模式）
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

MANIFEST="{}"
if [ -f .build-cache/manifest.json ]; then
	MANIFEST=$(cat .build-cache/manifest.json)
fi

# 基础镜像指纹：pin 的 tag 当前内容（patch 更新时变化）
ALPINE_FP=$(curl -sf "https://hub.docker.com/v2/repositories/library/alpine/tags/${BASE_ALPINE##*:}" | jq -c '[.images[].digest] | sort') || ALPINE_FP="unknown"
DEBIAN_FP=$(curl -sf "https://hub.docker.com/v2/repositories/library/debian/tags/${BASE_DEBIAN##*:}" | jq -c '[.images[].digest] | sort') || DEBIAN_FP="unknown"

BASE_CHANGED="false"
if [ "$(printf '%s' "$MANIFEST" | jq -r '.base_alpine // "none"')" != "$ALPINE_FP" ] ||
	[ "$(printf '%s' "$MANIFEST" | jq -r '.base_debian // "none"')" != "$DEBIAN_FP" ]; then
	BASE_CHANGED="true"
fi

BETA_MODE="false"
if [ "$GITHUB_REF" = "refs/heads/dev" ]; then
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
