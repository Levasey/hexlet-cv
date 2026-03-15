# Этап сборки
FROM gradle:8.14.1-jdk17 AS build
WORKDIR /app

# Копируем только файлы для зависимостей (для кэширования)
COPY build.gradle.kts settings.gradle.kts gradle.properties ./
COPY gradle ./gradle

# Скачиваем зависимости
RUN gradle dependencies --no-daemon || true

# Копируем конфиг checkstyle и исходники
COPY config ./config
COPY src ./src
RUN gradle build --no-daemon -x test

# Этап запуска
FROM eclipse-temurin:22-jre-alpine
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