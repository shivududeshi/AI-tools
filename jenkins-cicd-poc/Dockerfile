# ============================================================
# Dockerfile for Spring PetClinic
# Multi-stage build: Build with Maven, run with JRE
# Java 17 required (matches pom.xml)
# ============================================================

# ---- Stage 1: Build ----
FROM maven:3.9.6-eclipse-temurin-17 AS builder

WORKDIR /app

# Copy pom.xml first to leverage Docker layer caching for dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B --no-transfer-progress

# Copy source and build (skip tests — tests run as a separate CI stage)
COPY src ./src
RUN mvn clean package -DskipTests -B --no-transfer-progress

# ---- Stage 2: Runtime ----
FROM eclipse-temurin:17-jre-jammy

# Non-root user for security
RUN groupadd --system petclinic && useradd --system --gid petclinic petclinic

WORKDIR /app

# Copy the fat JAR from the builder stage
COPY --from=builder /app/target/spring-petclinic-*.jar app.jar

# Set correct ownership
RUN chown petclinic:petclinic app.jar

USER petclinic

# Spring Boot actuator health endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
