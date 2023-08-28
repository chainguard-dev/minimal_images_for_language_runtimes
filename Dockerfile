FROM cgr.dev/chainguard/maven as build

WORKDIR /app

COPY .mvn/ .mvn
COPY mvnw pom.xml ./
COPY src ./src
RUN ./mvnw package

FROM cgr.dev/chainguard/jre

COPY --from=build /app/target/spring-petclinic-3.1.0-SNAPSHOT.jar /

ENTRYPOINT ["java", "-jar", "/spring-petclinic-3.1.0-SNAPSHOT.jar"]
