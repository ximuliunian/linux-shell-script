#!/bin/bash

# 检查参数数量
if [ $# -ne 5 ]; then
    echo "用法: $0 <挂载目录> <Web端口> <SSH端口> <容器名称> <镜像名称>"
    echo "例子: $0 /data/docker/gitea 26625 26626 gitea gitea/gitea:latest"
    echo "前置条件:"
    echo "  1. 具备 Docker 环境"
    echo "  2. 已拉取 Gitea 镜像（docker pull gitea/gitea:latest）"
    exit 1
fi

# 定义变量
MOUNT_DIR="$1"
HOST_PORT_WEB="$2"
HOST_PORT_SSH="$3"
GITEA_NAME="$4"
GITEA_IMAGE="$5"

# 创建挂载目录结构
echo "正在创建挂载目录..."
mkdir -p "${MOUNT_DIR}"

# 清理已存在的容器
echo "正在清理已存在的容器..."
docker stop "${GITEA_NAME}" 2>/dev/null || true
docker rm "${GITEA_NAME}" 2>/dev/null || true

# 设置目录权限（Gitea 容器内以 uid=1000 运行）
echo "正在设置目录权限..."
chown -R 1000:1000 "${MOUNT_DIR}"

# 运行容器
echo "正在启动 Gitea 容器..."
docker run -d \
    --name "${GITEA_NAME}" \
    --restart unless-stopped \
    -p "${HOST_PORT_WEB}:3000" \
    -p "${HOST_PORT_SSH}:22" \
    -v "${MOUNT_DIR}:/data" \
    -e GITEA__database__DB_TYPE=sqlite3 \
    "${GITEA_IMAGE}"

# 验证容器状态
if [ $? -eq 0 ]; then
    echo "✅ Gitea 容器已启动"
    echo "   容器名称: ${GITEA_NAME}"
    echo "   使用镜像: ${GITEA_IMAGE}"
    echo "   Web 访问地址: http://localhost:${HOST_PORT_WEB}"
    echo "   SSH 端口: ${HOST_PORT_SSH}"
    echo "   数据存储路径: ${MOUNT_DIR}"
    echo "   查看日志: docker logs -f ${GITEA_NAME}"
else
    echo "❌ 容器启动失败，请检查日志: docker logs ${GITEA_NAME}"
    exit 1
fi