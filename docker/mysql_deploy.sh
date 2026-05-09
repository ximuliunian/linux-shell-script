#!/bin/bash

# 检查参数数量
if [ $# -ne 5 ]; then
    echo "用法: $0 <挂载目录> <监听端口> <容器名称> <MySQL Root密码> <镜像名称>"
    echo "例子: $0 ~/apps/mysql 3306 mysql_dev MyStrongPass123 mysql:8.0"
    echo "前置条件:"
    echo "  1. 具备 Docker 环境"
    echo "  2. 已拉取对应镜像（docker pull mysql）"
    exit 1
fi

# 定义变量
MOUNT_DIR=$1
HOST_PORT=$2
MYSQL_NAME=$3
MYSQL_ROOT_PWD=$4
MYSQL_IMAGE=$5

# 创建挂载目录结构
echo "正在创建挂载目录..."
mkdir -p "${MOUNT_DIR}/conf"
mkdir -p "${MOUNT_DIR}/data"
mkdir -p "${MOUNT_DIR}/log"

# 清理已存在的mysql容器
echo "正在清理已存在的mysql容器..."
docker stop "${MYSQL_NAME}" 2>/dev/null || true
docker rm "${MYSQL_NAME}" 2>/dev/null || true

# 创建临时容器用于提取配置文件
echo "正在创建临时容器以提取配置文件..."
docker create --name temp-mysql "${MYSQL_IMAGE}" > /dev/null
docker start temp-mysql > /dev/null

# 稍作等待确保容器内文件系统就绪
sleep 2

# 从临时容器复制配置文件
# 兼容MySQL和MariaDB的不同配置文件位置
echo "正在复制配置文件..."
docker cp temp-mysql:/etc/mysql/my.cnf "${MOUNT_DIR}/conf/my.cnf" 2>/dev/null || \
docker cp temp-mysql:/etc/my.cnf "${MOUNT_DIR}/conf/my.cnf" 2>/dev/null || \
echo "  [提示] 未找到主配置文件，仅复制 conf.d 目录..."

docker cp temp-mysql:/etc/mysql/conf.d "${MOUNT_DIR}/conf/" 2>/dev/null || \
docker cp temp-mysql:/etc/my.cnf.d "${MOUNT_DIR}/conf/" 2>/dev/null || \
echo "  [提示] 未找到 conf.d 目录"

# 清理临时容器
echo "正在清理临时容器..."
docker stop temp-mysql > /dev/null
docker rm temp-mysql > /dev/null

# 运行最终的mysql容器
echo "正在启动MySQL容器..."
docker run -d \
    -p "${HOST_PORT}:3306" \
    --name "${MYSQL_NAME}" \
    -v "${MOUNT_DIR}/conf/my.cnf:/etc/mysql/my.cnf" \
    -v "${MOUNT_DIR}/conf/conf.d:/etc/mysql/conf.d" \
    -v "${MOUNT_DIR}/data:/var/lib/mysql" \
    -v "${MOUNT_DIR}/log:/var/log/mysql" \
    -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PWD}" \
    --restart unless-stopped \
    "${MYSQL_IMAGE}"

echo "✅ MySQL容器已启动"
echo "   容器名称: ${MYSQL_NAME}"
echo "   使用镜像: ${MYSQL_IMAGE}"
echo "   宿主机访问端口: ${HOST_PORT}"
echo "   挂载目录: ${MOUNT_DIR}"
echo "   Root密码: ${MYSQL_ROOT_PWD}"
