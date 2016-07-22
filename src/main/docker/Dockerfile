FROM frolvlad/alpine-oraclejdk8:slim
VOLUME /tmp
ADD ${artifactId}-${version}.jar ${artifactId}-${version}.jar
RUN sh -c 'touch /${artifactId}-${version}.jar'
ENTRYPOINT ["java","-jar","/${artifactId}-${version}.jar"]