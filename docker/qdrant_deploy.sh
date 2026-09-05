#!/bin/bash

# 检查参数数量
if [ $# -ne 5 ]; then
    echo "用法: $0 <挂载目录> <HTTP端口> <gRPC端口> <容器名称> <镜像名称>"
    echo "例子: $0 ~/apps/qdrant 6333 6334 qdrant qdrant/qdrant:latest"
    echo "前置条件:"
    echo "  1. 具备 Docker 环境"
    echo "  2. 已拉取 Qdrant 镜像（docker pull qdrant/qdrant）"
    exit 1
fi

# 定义变量
MOUNT_DIR="$1"
HOST_PORT_HTTP="$2"
HOST_PORT_GRPC="$3"
QDRANT_NAME="$4"
QDRANT_IMAGE="$5"

# 创建挂载目录结构
echo "正在创建挂载目录..."
mkdir -p "${MOUNT_DIR}/storage"
mkdir -p "${MOUNT_DIR}/config"
mkdir -p "${MOUNT_DIR}/snapshots"


# 清理已存在的容器
echo "正在清理已存在的容器..."
docker stop "${QDRANT_NAME}" 2>/dev/null || true
docker rm "${QDRANT_NAME}" 2>/dev/null || true

# 运行容器
echo "正在启动 Qdrant 容器..."
docker run -d \
    --name "${QDRANT_NAME}" \
    --restart unless-stopped \
    -p "${HOST_PORT_HTTP}:6333" \
    -p "${HOST_PORT_GRPC}:6334" \
    -v "${MOUNT_DIR}/storage:/qdrant/storage" \
    -v "${MOUNT_DIR}/config:/qdrant/config" \
    -v "${MOUNT_DIR}/snapshots:/qdrant/snapshots" \
    "${QDRANT_IMAGE}"

# 验证容器状态
if [ $? -eq 0 ]; then
    echo "✅ Qdrant 容器已启动"
    echo "   容器名称: ${QDRANT_NAME}"
    echo "   使用镜像: ${QDRANT_IMAGE}"
    echo "   HTTP API 地址: http://localhost:${HOST_PORT_HTTP}"
    echo "   gRPC 端口: ${HOST_PORT_GRPC}"
    echo "   数据存储路径: ${MOUNT_DIR}/storage"
    echo "   配置文件路径: ${MOUNT_DIR}/config"
    echo "   快照路径: ${MOUNT_DIR}/snapshots"
    echo "   查看日志: docker logs -f ${QDRANT_NAME}"
else
    echo "❌ 容器启动失败，请检查日志: docker logs ${QDRANT_NAME}"
    exit 1
fi