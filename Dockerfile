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

# Копируем только файлы для зависимостей (для кэширования)
COPY --from=frontend-build /app/frontend/dist /app/src/main/resources/static/
COPY build.gradle.kts settings.gradle.kts gradle.properties ./
COPY gradle ./gradle

# Скачиваем зависимости
RUN gradle dependencies --no-daemon || true

# Копируем конфиг checkstyle и исходники
COPY config ./config
COPY src ./src
RUN gradle build --no-daemon -x test

# ---- Stage 3: Runtime ----
FROM eclipse-temurin:24-jre-alpine
WORKDIR /app

# Создаем пользователя (безопасность)
RUN adduser -D -H -h /app appuser

# Копируем jar из этапа сборки
COPY --from=build /app/build/libs/*.jar app.jar

# Права доступа
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]