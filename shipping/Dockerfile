FROM maven:3.9-eclipse-temurin-8 AS build

WORKDIR /opt/shipping

COPY pom.xml /opt/shipping/
RUN mvn dependency:resolve
COPY src /opt/shipping/src/
RUN mvn package

#
# Run
#
FROM eclipse-temurin:8-jdk

EXPOSE 8080

WORKDIR /opt/shipping

# Download the OpenTelemetry Java Agent
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar .

ENV CART_ENDPOINT=cart:8080
ENV DB_HOST=mysql

COPY --from=build /opt/shipping/target/shipping-1.0.jar shipping.jar

# Add -javaagent argument to enable OpenTelemetry
CMD [ "java", "-javaagent:opentelemetry-javaagent.jar", "-Xmn256m", "-Xmx768m", "-jar", "shipping.jar" ]