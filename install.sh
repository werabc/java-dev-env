#!/bin/bash
set -e
GHCR=ghcr.io/werabc
echo "=== Java开发环境搭建 ==="
echo "[1/5] Redis 7..."
docker pull ${GHCR}/redis:7-alpine
echo "[2/5] JDK 17 (eclipse-temurin)..."
docker pull ${GHCR}/eclipse-temurin:17-jre-alpine
echo "[3/5] Maven 3.9..."
docker pull ${GHCR}/maven:3.9-eclipse-temurin-17
echo "[4/5] Node.js 20..."
docker pull ${GHCR}/node:20-alpine
echo "[5/5] Nginx 1.27..."
docker pull ${GHCR}/nginx:1.27-alpine
docker run -d --name redis-dev -p 6379:6379 ${GHCR}/redis:7-alpine 2>/dev/null || true
echo "=== 完成 ==="
echo "Redis:     localhost:6379"
echo "Java构建:  docker run -it --rm -v $(pwd):/build ${GHCR}/maven:3.9-eclipse-temurin-17"
echo "Java运行:  docker run -it --rm ${GHCR}/eclipse-temurin:17-jre-alpine"
echo "前端构建:  docker run -it --rm -v $(pwd):/app ${GHCR}/node:20-alpine"
echo "前端服务:  docker run -it --rm -p 80:80 ${GHCR}/nginx:1.27-alpine"