# 运行镜像（默认 Alpine，可用 --build-arg BASE_IMAGE=... 切换基础镜像）
ARG BASE_IMAGE=public.ecr.aws/docker/library/alpine:3.24
FROM ${BASE_IMAGE}

ARG TARGETOS
ARG TARGETARCH

LABEL maintainer="git@blazesnow.org"
LABEL repository="https://github.com/BlazeSnow/Caddy"

# 创建配置和数据目录
RUN mkdir -p /config /data

# 补齐依赖（按基础镜像的包管理器选择）
RUN if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache ca-certificates libcap mailcap; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update && apt-get install -y --no-install-recommends ca-certificates libcap2-bin mailcap && rm -rf /var/lib/apt/lists/*; \
    fi

# 复制 CI 中构建好的对应架构可执行文件
COPY ./dist/${TARGETOS}_${TARGETARCH}/caddy /usr/bin/caddy

# 设置可执行文件权限
RUN chmod +x /usr/bin/caddy

# 复制默认配置文件
COPY ./Caddyfile /etc/caddy/Caddyfile

# 设置存储目录
ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data

# 开放端口
EXPOSE 80 443 443/udp 2019

# 运行命令
CMD ["/usr/bin/caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
