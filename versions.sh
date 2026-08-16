#!/bin/bash
# versions.sh：查询 Caddy/插件最新版本，读取已有镜像的版本信息判断哪些需要构建
#
# 判定依据（镜像自身即构建记录，替代原来的 cache manifest）：
#   - base：读取 GHCR 上 caddy-base 的 base-upstream-digest-* label，与当前上游
#     alpine/debian 对应架构 digest 对比；不一致或镜像缺失则重建（并级联重建全部插件）
#   - 插件：读取 blazesnow/caddy(-beta):<插件> 的 caddy-version / plugin-version label，
#     与当前 @latest 对比；不一致或镜像缺失则重建
#   - tag 触发或 FORCE_BUILD=true：全部强制重建
#
# 依赖环境变量：
#   GITHUB_OUTPUT / GITHUB_TOKEN / GITHUB_REF
#   BASE_ALPINE / BASE_DEBIAN                上游 base 镜像 pin
#   BASE_IMAGE_REPO / BASE_TAG_ALPINE / BASE_TAG_DEBIAN / BASE_TAG_SUFFIX
#   GHCR_IMAGE_PREFIX                        插件镜像前缀（ghcr.io/blazesnow/caddy 或 -beta）
#   BETA_PLUGINS / FORCE_BUILD
set -eu

jq -e 'type == "array" and length > 0' plugins.json >/dev/null || {
	echo "::error::plugins.json 无效或为空"
	exit 1
}

FORCE="false"
[ "${FORCE_BUILD:-}" = "true" ] && FORCE="true"
# 推送 tag（发布 beta/稳定版）视为强制构建：忽略跳过逻辑，全部插件重建
[[ "$GITHUB_REF" == refs/tags/* ]] && FORCE="true"

BETA_MODE="false"
if [ "$GITHUB_REF" = "refs/heads/dev" ] || [[ "$GITHUB_REF" == refs/tags/*-beta* ]]; then
	BETA_MODE="true"
	echo "beta 模式：仅考虑 $BETA_PLUGINS"
fi

CADDY=$(go list -m -json github.com/caddyserver/caddy/v2@latest | jq -r '.Version')
[ -n "$CADDY" ] || {
	echo "查询 caddy 最新版本失败" >&2
	exit 1
}

# 读取镜像 labels（GHCR registry API）；镜像缺失或查询失败返回空对象
image_labels() {
	local repo="${1#ghcr.io/}" tag="$2" token index digest man cfg
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		token=$(curl -sfL -u "x:${GITHUB_TOKEN}" "https://ghcr.io/token?scope=repository:${repo}:pull" | jq -r '.token') || {
			echo '{}'
			return
		}
	else
		# 无 token（如本地测试）时走匿名访问，仅适用于公开镜像
		token=$(curl -sfL "https://ghcr.io/token?scope=repository:${repo}:pull" | jq -r '.token') || {
			echo '{}'
			return
		}
	fi
	index=$(curl -sfL -H "Authorization: Bearer ${token}" \
		-H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json" \
		"https://ghcr.io/v2/${repo}/manifests/${tag}") || {
		echo '{}'
		return
	}
	digest=$(printf '%s' "$index" | jq -r '.manifests[] | select(.platform.architecture == "amd64") | .digest' | head -1) || {
		echo '{}'
		return
	}
	[ -n "$digest" ] || {
		echo '{}'
		return
	}
	man=$(curl -sfL -H "Authorization: Bearer ${token}" \
		-H "Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json" \
		"https://ghcr.io/v2/${repo}/manifests/${digest}") || {
		echo '{}'
		return
	}
	cfg=$(printf '%s' "$man" | jq -r '.config.digest') || {
		echo '{}'
		return
	}
	# blob 下载会 307 重定向到存储，需 -L 跟随；先抓原始响应避免空输入时 jq 退出码为 0 的误判
	raw=$(curl -sfL -H "Authorization: Bearer ${token}" \
		-H "Accept: application/vnd.oci.image.config.v1+json" \
		"https://ghcr.io/v2/${repo}/blobs/${cfg}") || {
		echo '{}'
		return
	}
	[ -n "$raw" ] || {
		echo '{}'
		return
	}
	printf '%s' "$raw" | jq -c '.config.Labels // {}'
}

# 上游 alpine/debian 按架构 digest 映射（amd64/arm64）；查询失败返回空对象（跳过比对）
upstream_digests() {
	local url="$1" out
	out=$(curl -sf "$url" | jq -c '[.images[] | select(.architecture == "amd64" or .architecture == "arm64") | {(.architecture): .digest}] | add')
	[ -n "$out" ] && [ "$out" != "null" ] || out="{}"
	echo "$out"
}
ALPINE_UP=$(upstream_digests "https://hub.docker.com/v2/repositories/library/alpine/tags/${BASE_ALPINE##*:}")
DEBIAN_UP=$(upstream_digests "https://hub.docker.com/v2/repositories/library/debian/tags/${BASE_DEBIAN##*:}")

# 某 flavor 的 base 是否需要重建：上游查询失败时跳过比对，镜像缺失或 digest 不一致则重建
base_flavor_changed() {
	local labels="$1" upstream="$2" arch label current
	[ "$upstream" = "{}" ] && return 1
	for arch in amd64 arm64; do
		label=$(printf '%s' "$labels" | jq -r --arg k "base-upstream-digest-$arch" '.[$k] // ""')
		current=$(printf '%s' "$upstream" | jq -r --arg arch "$arch" '.[$arch] // ""')
		if [ -z "$label" ] || [ "$label" != "$current" ]; then
			return 0
		fi
	done
	return 1
}

BASE_CHANGED="false"
[ "$FORCE" = "true" ] && BASE_CHANGED="true"
if [ "$BASE_CHANGED" != "true" ]; then
	ALPINE_LABELS=$(image_labels "$BASE_IMAGE_REPO" "${BASE_TAG_ALPINE}${BASE_TAG_SUFFIX}")
	DEBIAN_LABELS=$(image_labels "$BASE_IMAGE_REPO" "${BASE_TAG_DEBIAN}${BASE_TAG_SUFFIX}")
	if base_flavor_changed "$ALPINE_LABELS" "$ALPINE_UP" || base_flavor_changed "$DEBIAN_LABELS" "$DEBIAN_UP"; then
		BASE_CHANGED="true"
	fi
fi
echo "base_changed=$BASE_CHANGED"
echo "force=$FORCE"

# 插件矩阵
if [ "$BETA_MODE" = "true" ]; then
	SELECTED=$(jq -c --arg list "$BETA_PLUGINS" '[.[] | select(. as $p | ($list | split(" ") | index($p.name)) != null)] | .[]' plugins.json)
else
	SELECTED=$(jq -c '.[]' plugins.json)
fi

MATRIX='[]'
while IFS= read -r entry; do
	name=$(jq -r '.name' <<<"$entry")
	context=$(jq -r '.context' <<<"$entry")
	plugin_version=$(go list -m -json "${context}@latest" | jq -r '.Version')
	[ -n "$plugin_version" ] || {
		echo "查询 $name 最新版本失败（$context）" >&2
		exit 1
	}

	NEED="false"
	if [ "$FORCE" = "true" ] || [ "$BASE_CHANGED" = "true" ]; then
		NEED="true"
		echo "  $name：强制构建（force=$FORCE base_changed=$BASE_CHANGED）"
	else
		labels=$(image_labels "${GHCR_IMAGE_PREFIX}" "$name")
		built_caddy=$(printf '%s' "$labels" | jq -r '.["caddy-version"] // ""')
		built_plugin=$(printf '%s' "$labels" | jq -r '.["plugin-version"] // ""')
		if [ "$built_caddy" != "$CADDY" ] || [ "$built_plugin" != "$plugin_version" ]; then
			NEED="true"
		fi
		echo "  $name：镜像 caddy=$built_caddy plugin=$built_plugin，最新 caddy=$CADDY plugin=$plugin_version -> $NEED"
	fi

	if [ "$NEED" = "true" ]; then
		MATRIX=$(printf '%s' "$MATRIX" | jq -c \
			--arg name "$name" --arg context "$context" --arg plugin_version "$plugin_version" \
			'. + [{name: $name, context: $context, plugin_version: $plugin_version}]')
	fi
done <<<"$SELECTED"

echo "matrix=$MATRIX"
echo "caddy=$CADDY" >>"$GITHUB_OUTPUT"
echo "matrix=$MATRIX" >>"$GITHUB_OUTPUT"
echo "base_changed=$BASE_CHANGED" >>"$GITHUB_OUTPUT"
