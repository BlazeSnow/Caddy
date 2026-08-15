#!/bin/bash
# write-manifest.sh：把本次构建结果写入构建清单，供下次跳过判断使用
#
# 依赖环境变量：ALL_VERSIONS（versions.sh 输出的 all_versions）
set -eu

mkdir -p .build-cache
echo "$ALL_VERSIONS" > .build-cache/manifest.json
