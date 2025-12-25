# 构建镜像
FROM ghcr.io/blazesnow/caddy:builder

# 开始构建
ARG PLUGIN
RUN xcaddy build --with ${PLUGIN} --output /caddy

# 运行镜像
FROM ghcr.io/blazesnow/alpine:latest

LABEL maintainer="hello@blazesnow.com"
LABEL repository="https://github.com/BlazeSnow/Caddy"

# 创建配置和数据目录
RUN mkdir -p /config /data

# 补齐依赖
RUN apk add --no-cache ca-certificates libcap mailcap

# 复制可执行文件
COPY --from=builder /caddy /usr/bin/caddy

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
