#!/bin/bash

# 检查参数数量
if [ $# -ne 5 ]; then
    echo "用法: $0 <挂载目录> <监听端口> <容器名称> <密码> <镜像名称>"
    echo "例子: $0 ~/apps/postgres 5432 postgres_dev MyStrongPass123 postgres:16-alpine"
    echo "前置条件:"
    echo "  1. 具备 Docker 环境"
    echo "  2. 已拉取 PostgreSQL 镜像（docker pull postgres）"
    exit 1
fi

# 定义变量
MOUNT_DIR="$1"
HOST_PORT="$2"
PG_NAME="$3"
PG_PWD="$4"
PG_IMAGE="$5"

# 创建挂载目录结构
echo "正在创建挂载目录..."
mkdir -p "${MOUNT_DIR}/data"
mkdir -p "${MOUNT_DIR}/log"

# 清理已存在的容器
echo "正在清理已存在的容器..."
docker stop "${PG_NAME}" 2>/dev/null || true
docker rm "${PG_NAME}" 2>/dev/null || true
docker rm temp-postgres 2>/dev/null || true

# 使用临时容器初始化数据目录并设置密码
echo "正在初始化 PostgreSQL 数据（临时容器）..."
docker run --name temp-postgres -d \
    -e "POSTGRES_PASSWORD=${PG_PWD}" \
    -v "${MOUNT_DIR}/data:/var/lib/postgresql/data" \
    "${PG_IMAGE}"

# 等待数据库就绪
echo "等待 PostgreSQL 初始化完成..."
until docker logs temp-postgres 2>&1 | grep -q 'database system is ready to accept connections'; do
    sleep 2
done

# 停止临时容器（数据已保留在挂载目录）
echo "停止临时容器..."
docker stop temp-postgres > /dev/null
docker rm temp-postgres > /dev/null

# 修改配置文件（使 PostgreSQL 监听所有地址，并设置日志目录）
echo "正在调整配置文件..."
if [ -f "${MOUNT_DIR}/data/postgresql.conf" ]; then
    sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" "${MOUNT_DIR}/data/postgresql.conf"
    sed -i "s/^#port = 5432/port = 5432/" "${MOUNT_DIR}/data/postgresql.conf"
    # 设置日志目录
    sed -i "s|^#log_directory = 'log'|log_directory = '/var/log/postgresql'|" "${MOUNT_DIR}/data/postgresql.conf"
    # 确保日志记录开启
    sed -i "s/^#logging_collector = off/logging_collector = on/" "${MOUNT_DIR}/data/postgresql.conf"
else
    echo "  [警告] 未找到 postgresql.conf，请检查数据目录"
fi

# 调整 pg_hba.conf 允许所有主机连接（可选）
if [ -f "${MOUNT_DIR}/data/pg_hba.conf" ]; then
    echo "host all all 0.0.0.0/0 scram-sha-256" >> "${MOUNT_DIR}/data/pg_hba.conf"
fi

# 运行正式容器（挂载数据目录和日志目录）
echo "正在启动 PostgreSQL 容器..."
docker run -d \
    --name "${PG_NAME}" \
    --restart unless-stopped \
    -p "${HOST_PORT}:5432" \
    -v "${MOUNT_DIR}/data:/var/lib/postgresql/data" \
    -v "${MOUNT_DIR}/log:/var/log/postgresql" \
    "${PG_IMAGE}"

# 验证容器状态
if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL 容器已启动"
    echo "   容器名称: ${PG_NAME}"
    echo "   使用镜像: ${PG_IMAGE}"
    echo "   宿主机访问端口: ${HOST_PORT}"
    echo "   挂载目录: ${MOUNT_DIR}"
    echo "   密码: ${PG_PWD}"
    echo "   连接命令: psql -h localhost -p ${HOST_PORT} -U postgres"
    echo "   ⚠️ 如果连接提示权限错误，请检查数据目录属主是否为 999:999"
else
    echo "❌ 容器启动失败，请检查日志: docker logs ${PG_NAME}"
    exit 1
fi