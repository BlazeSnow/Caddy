# 运行镜像：从预构建的静态基础镜像（ghcr.io/blazesnow/caddy-base）出发，
# 仅注入 CI 编译好的对应架构 caddy 二进制。静态层见 ./Dockerfile.base。
ARG BASE_IMAGE=ghcr.io/blazesnow/caddy-base:alpine-3.24
FROM ${BASE_IMAGE}

ARG TARGETOS
ARG TARGETARCH

# 发布版本（CI 从 VERSION 文件注入 build-arg）
ARG VERSION=dev
LABEL org.opencontainers.image.version="${VERSION}"

# 注入 CI 中构建好的对应架构可执行文件（COPY --chmod 设置执行位，免去 RUN 层）
COPY --chmod=755 ./dist/${TARGETOS}_${TARGETARCH}/caddy /usr/bin/caddy
