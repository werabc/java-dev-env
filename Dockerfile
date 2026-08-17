FROM ghcr.io/werabc/eclipse-temurin:17-jre-alpine
RUN apk add --no-cache bash curl
WORKDIR /workspace
CMD ["/bin/bash"]
