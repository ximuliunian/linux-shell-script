#!/bin/bash

# 检查参数数量
if [ $# -ne 5 ]; then
    echo "用法: $0 <挂载目录> <监听端口> <容器名称> <Redis密码> <镜像名称>"
    echo "例子: $0 ~/apps/redis 6379 redis mypassword redis:7-alpine"
    echo "前置条件:"
    echo "  1. 具备 Docker 环境"
    echo "  2. 已拉取 Redis 镜像（docker pull redis）"
    exit 1
fi

# 定义变量
MOUNT_DIR="$1"
HOST_PORT="$2"
REDIS_NAME="$3"
REDIS_PWD="$4"
REDIS_IMAGE="$5"

# 创建挂载目录结构
echo "正在创建挂载目录..."
mkdir -p "${MOUNT_DIR}/data"
mkdir -p "${MOUNT_DIR}/conf"
mkdir -p "${MOUNT_DIR}/log"

# 修复日志目录权限（Redis 容器内用户 UID 通常为 999）
chown 999:999 "${MOUNT_DIR}/log" 2>/dev/null || echo "  [提示] 无法修改目录属主，请确保容器有日志写入权限"

# 清理已存在的容器
echo "正在清理已存在的容器..."
docker stop "${REDIS_NAME}" 2>/dev/null || true
docker rm "${REDIS_NAME}" 2>/dev/null || true

# 直接生成配置文件（不依赖临时容器）
echo "正在生成 Redis 配置文件..."
cat <<EOF > "${MOUNT_DIR}/conf/redis.conf"
bind 0.0.0.0
port 6379
requirepass ${REDIS_PWD}
appendonly yes
logfile /var/log/redis/redis.log
dir /data
EOF

# 运行容器
echo "正在启动 Redis 容器..."
docker run -d \
    --name "${REDIS_NAME}" \
    --restart unless-stopped \
    -p "${HOST_PORT}:6379" \
    -v "${MOUNT_DIR}/data:/data" \
    -v "${MOUNT_DIR}/conf/redis.conf:/usr/local/etc/redis/redis.conf" \
    -v "${MOUNT_DIR}/log:/var/log/redis" \
    "${REDIS_IMAGE}" \
    redis-server /usr/local/etc/redis/redis.conf

# 验证容器状态
if [ $? -eq 0 ]; then
    echo "✅ Redis 容器已启动"
    echo "   容器名称: ${REDIS_NAME}"
    echo "   使用镜像: ${REDIS_IMAGE}"
    echo "   宿主机访问端口: ${HOST_PORT}"
    echo "   挂载目录: ${MOUNT_DIR}"
    echo "   密码: ${REDIS_PWD}"
    echo "   连接命令: redis-cli -h localhost -p ${HOST_PORT} -a ${REDIS_PWD}"
else
    echo "❌ 容器启动失败，请检查日志: docker logs ${REDIS_NAME}"
    exit 1
fi