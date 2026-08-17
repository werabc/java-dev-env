#!/bin/bash
set -e
echo "=== Java开发环境搭建 ==="
GHCR=ghcr.io/werabc
echo "[1/4] 拉取Redis..."
docker pull ${GHCR}/redis:7-alpine
echo "[2/4] 拉取JDK 17..."
docker pull ${GHCR}/eclipse-temurin:17-jre-alpine
echo "[3/4] 拉取Node.js 20..."
docker pull ${GHCR}/node:20-alpine
echo "[4/4] 拉取Nginx 1.27..."
docker pull ${GHCR}/nginx:1.27-alpine
docker run -d --name redis-dev -p 6379:6379 ${GHCR}/redis:7-alpine
echo "=== 完成 ==="
echo "Redis: localhost:6379"
echo "Java: docker run -it --rm java-dev:17"
echo "Node: docker run -it --rm node:20-alpine"
echo "Nginx: docker run -it --rm -p 80:80 nginx:1.27-alpine"