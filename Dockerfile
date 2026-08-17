FROM eclipse-temurin:17-jdk
RUN apt-get update && apt-get install -y wget curl unzip \
    && wget https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz \
    && tar -xzf apache-maven-3.9.9-bin.tar.gz -C /opt \
    && ln -s /opt/apache-maven-3.9.9/bin/mvn /usr/local/bin/mvn \
    && rm apache-maven-3.9.9-bin.tar.gz \
    && apt-get clean
ENV MAVEN_HOME=/opt/apache-maven-3.9.9
ENV PATH=${MAVEN_HOME}/bin:
WORKDIR /workspace
CMD ["/bin/bash"]