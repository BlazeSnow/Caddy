# 运行镜像：从预构建的静态基础镜像（ghcr.io/blazesnow/caddy-base）出发，
# 仅注入 CI 编译好的对应架构 caddy 二进制。静态层见 ./Dockerfile.base。
ARG BASE_IMAGE=ghcr.io/blazesnow/caddy-base:alpine-3.24
FROM ${BASE_IMAGE}

ARG TARGETOS
ARG TARGETARCH

# 发布版本（CI 注入 build-arg）：生产为 VERSION 文件的正式版号，beta 为 tag 名或 dev
ARG VERSION=dev
LABEL org.opencontainers.image.version="${VERSION}"
# 本次构建的 Caddy 和插件版本（CI 注入），供 docker inspect 查看镜像构成
ARG CADDY_VERSION
LABEL caddy-version="${CADDY_VERSION}"
ARG PLUGIN_VERSION
LABEL plugin-version="${PLUGIN_VERSION}"

# 注入 CI 中构建好的对应架构可执行文件（COPY --chmod 设置执行位，免去 RUN 层）
COPY --chmod=755 ./dist/${TARGETOS}_${TARGETARCH}/caddy /usr/bin/caddy
