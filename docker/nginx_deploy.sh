#!/bin/bash

# 检查参数数量
if [ $# -ne 4 ]; then
    echo "用法: $0 <挂载目录> <监听端口> <容器名称> <镜像名称>"
    echo "例子: $0 ~/apps/nginx 8080 nginx nginx:latest"
    echo "前置条件:"
    echo "  1. 具备 Docker 环境"
    echo "  2. 已拉取 Nginx 镜像（docker pull nginx）"
    exit 1
fi

# 定义变量
MOUNT_DIR=$1
HOST_PORT=$2
NGINX_NAME=$3
NGINX_IMAGE=$4

# 创建挂载目录结构
echo "正在创建挂载目录..."
mkdir -p "${MOUNT_DIR}/conf"
mkdir -p "${MOUNT_DIR}/log"
mkdir -p "${MOUNT_DIR}/html"

# 清理已存在的nginx容器
echo "正在清理已存在的nginx容器..."
docker stop "${NGINX_NAME}" 2>/dev/null || true
docker rm "${NGINX_NAME}" 2>/dev/null || true

# 创建临时容器用于提取配置文件
echo "正在创建临时容器以提取配置文件..."
docker create --name temp-nginx "${NGINX_IMAGE}" > /dev/null
docker start temp-nginx > /dev/null

# 从临时容器复制配置文件和目录
echo "正在复制配置文件..."
docker cp temp-nginx:/etc/nginx/nginx.conf "${MOUNT_DIR}/conf/nginx.conf"
docker cp temp-nginx:/etc/nginx/conf.d "${MOUNT_DIR}/conf/"
docker cp temp-nginx:/usr/share/nginx/html "${MOUNT_DIR}/"

# 清理临时容器
echo "正在清理临时容器..."
docker stop temp-nginx > /dev/null
docker rm temp-nginx > /dev/null

# 运行最终的nginx容器
echo "正在启动nginx容器..."
docker run -d \
    -p "${HOST_PORT}:80" \
    --name "${NGINX_NAME}" \
    -v "${MOUNT_DIR}/conf/nginx.conf:/etc/nginx/nginx.conf" \
    -v "${MOUNT_DIR}/conf/conf.d:/etc/nginx/conf.d" \
    -v "${MOUNT_DIR}/log:/var/log/nginx" \
    -v "${MOUNT_DIR}/html:/usr/share/nginx/html" \
    "${NGINX_IMAGE}"

echo "✅ Nginx容器已启动"
echo "   宿主机访问端口: ${HOST_PORT}"
echo "   挂载目录: ${MOUNT_DIR}"
echo "   使用镜像: ${NGINX_IMAGE}"
