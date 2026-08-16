#!/bin/bash
# sync-readme.sh：把 README.md 同步为 Docker Hub 仓库描述
#
# 依赖环境变量：
#   DOCKER_USER    Docker Hub 用户名
#   DOCKER_TOKEN   Docker Hub token（secrets.TOKEN）
#   REPO           目标仓库（blazesnow/caddy 或 blazesnow/caddy-beta）
set -eu

TOKEN=$(curl -sf -X POST https://hub.docker.com/v2/users/login/ \
	-H "Content-Type: application/json" \
	-d "{\"username\":\"${DOCKER_USER}\",\"password\":\"${DOCKER_TOKEN}\"}" | jq -r '.token')

README=$(jq -Rs . README.md)

curl -sf -X PATCH "https://hub.docker.com/v2/repositories/${REPO}/" \
	-H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" \
	-d "{\"full_description\": ${README}}"

echo "已同步 README 到 ${REPO}"
