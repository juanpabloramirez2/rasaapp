# ─────────────────────────────────────────────────────────────────
# Stage 1 — Dependencias (capa cacheada: solo se re-ejecuta si
#           cambia pom.xml, NO cuando cambia el código fuente)
# ─────────────────────────────────────────────────────────────────
FROM --platform=linux/amd64 eclipse-temurin:17-jdk-alpine AS deps
WORKDIR /app

COPY mvnw .
COPY .mvn/ .mvn/
COPY pom.xml .

RUN chmod +x mvnw && \
    ./mvnw dependency:go-offline --no-transfer-progress -B

# ─────────────────────────────────────────────────────────────────
# Stage 2 — Build del JAR
# ─────────────────────────────────────────────────────────────────
FROM deps AS builder
COPY src ./src
RUN ./mvnw package -DskipTests --no-transfer-progress -B

# ─────────────────────────────────────────────────────────────────
# Stage 3 — Runtime (imagen mínima: solo JRE, sin Maven ni JDK)
# ─────────────────────────────────────────────────────────────────
FROM --platform=linux/amd64 eclipse-temurin:17-jdk-alpine AS runtime
WORKDIR /app

# Usuario sin privilegios de root
RUN addgroup -S rasaapp && adduser -S rasaapp -G rasaapp

# Copiar JAR compilado
COPY --from=builder /app/target/*.jar app.jar

# Directorios de datos con permisos correctos
RUN mkdir -p /app/uploads /app/logs && \
    chown -R rasaapp:rasaapp /app

USER rasaapp

# Volúmenes para datos persistentes fuera del contenedor
VOLUME ["/app/uploads", "/app/logs"]

EXPOSE 8080

# Health check usando el endpoint de Spring Actuator
HEALTHCHECK \
  --interval=30s \
  --timeout=10s \
  --start-period=90s \
  --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
