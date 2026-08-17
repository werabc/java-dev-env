#!/bin/bash
# Java开发环境一键搭建脚本
# 用法: ./install.sh

set -e

echo "=== Java开发环境搭建 ==="

# 1. 构建JDK+Maven镜像
echo "[1/3] 构建JDK 17 + Maven 3.9.9镜像..."
docker build -t java-dev:17 .
echo "✓ Java镜像构建完成"

# 2. 拉取Redis
echo "[2/3] 拉取Redis..."
docker pull redis:7-alpine 2>/dev/null || docker pull registry.cn-hongkong.aliyuncs.com/nick6610988017/redis:7
echo "✓ Redis镜像就绪"

# 3. 启动Redis容器
echo "[3/3] 启动Redis容器..."
docker run -d --name redis-dev -p 6379:6379 redis:7-alpine 2>/dev/null || docker run -d --name redis-dev -p 6379:6379 registry.cn-hongkong.aliyuncs.com/nick6610988017/redis:7
echo "✓ Redis已启动 (端口6379)"

echo ""
echo "=== 搭建完成 ==="
echo "Java+Maven: docker run -it --rm -v $(pwd):/workspace java-dev:17"
echo "Redis: localhost:6379"