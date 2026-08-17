# Java开发环境

一键搭建 JDK 17 + Maven 3.9.9 + Redis 7 开发环境。

## 使用方法

git clone https://github.com/werabc/java-dev-env.git
cd java-dev-env
chmod +x install.sh
./install.sh

## 包含组件

| 组件 | 版本 |
|------|------|
| JDK | 17 (eclipse-temurin) |
| Maven | 3.9.9 |
| Redis | 7 (alpine) |

## 启动后使用

docker run -it --rm -v $(pwd):/workspace java-dev:17
redis-cli ping
