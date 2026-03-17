# ---- Stage 1: Frontend build ----
FROM node:20 AS frontend-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npx vite build

# ---- Stage 2: Backend build ----
FROM gradle:8.14.1-jdk17 AS build
WORKDIR /app

COPY build.gradle.kts settings.gradle.kts gradle.properties ./
COPY gradle ./gradle

# Скачиваем зависимости
RUN gradle dependencies --no-daemon || true

# Копируем конфиг checkstyle и исходники
COPY config ./config
COPY src ./src

# Копируем фронтенд ПОСЛЕ src, чтобы static гарантированно попал в JAR
COPY --from=frontend-build /app/frontend/dist /app/src/main/resources/static/

# app.html без скриптов — React не загружается. Используем index.html (со скриптами) как шаблон Inertia
RUN mkdir -p /app/src/main/resources/templates && \
    cp /app/src/main/resources/static/index.html /app/src/main/resources/templates/app.html && \
    sed -i 's|<div id="app">[^<]*</div>|<div id="app" data-page='"'"'@PageObject@'"'"'></div>|' \
    /app/src/main/resources/templates/app.html && \
    grep -qE 'script[^>]*type=.*module' /app/src/main/resources/templates/app.html || (echo "ERROR: Script tags missing in app.html - frontend will not load" && exit 1)

RUN gradle build --no-daemon -x test

# ---- Stage 3: Runtime ----
FROM eclipse-temurin:24-jre-alpine
WORKDIR /app

# socat для Render: сразу слушаем PORT, проксируем в Spring Boot (стартует ~2–3 мин)
RUN apk add --no-cache socat

# Создаем пользователя (безопасность)
RUN adduser -D -H -h /app appuser

# Копируем jar и entrypoint
COPY --from=build /app/build/libs/*.jar app.jar
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

# Права доступа
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8080
ENTRYPOINT ["/app/docker-entrypoint.sh"]