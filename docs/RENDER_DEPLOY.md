# Деплой hexlet-cv на Render.com

Пошаговая инструкция по развёртыванию приложения на [Render.com](https://render.com) с использованием Docker и PostgreSQL.

---

## Предварительные требования

- Аккаунт на [render.com](https://render.com)
- Репозиторий проекта на GitHub или GitLab (привязанный к Render)
- Локально: закоммиченный и запушенный код с `Dockerfile` в корне репозитория

---

## Шаг 1. Создать PostgreSQL на Render

> **Важно:** Создайте базу данных до настройки переменных окружения — данные подключения понадобятся для Web Service.

1. Войдите в [Dashboard Render](https://dashboard.render.com).
2. Нажмите **New** → **PostgreSQL**.
3. Заполните:
   - **Name** — например, `hexlet-cv-db`.
   - **Database** — имя БД (или оставьте по умолчанию).
   - **User** и **Password** — запомните или сохраните (пароль показывается один раз).
   - **Region** — выберите ближайший к пользователям (например, Frankfurt).
4. Нажмите **Create Database**.
5. Дождитесь статуса **Available**.
6. В карточке базы откройте вкладку **Info** и скопируйте:
   - **Internal Database URL** (для сервиса на Render) или **External Database URL** (если подключаетесь извне).

Формат URL:  
`postgresql://USER:PASSWORD@HOST/DATABASE?sslmode=require`

---

## Шаг 2. Создать Web Service (Docker)

1. В Dashboard нажмите **New** → **Web Service**.
2. Подключите репозиторий:
   - Если ещё не подключён — **Connect account** (GitHub/GitLab) и выберите репозиторий `hexlet-cv`.
   - Выберите репозиторий и нажмите **Connect**.
3. Настройки сервиса:
   - **Name** — например, `hexlet-cv`.
   - **Region** — тот же, что у базы (например, Frankfurt).
   - **Branch** — ветка для деплоя (обычно `main` или `master`).
   - **Runtime** — **Docker**.
   - **Dockerfile Path** — оставьте `./Dockerfile` (если Dockerfile в корне).
   - **Instance Type** — Free или платный при необходимости.

---

## Шаг 3. Переменные окружения

В разделе **Environment** добавьте переменные для Web Service:

| Key | Value | Описание |
|-----|--------|----------|
| `SPRING_PROFILES_ACTIVE` | `prod` | Включение продакшен-конфигурации |
| `JDBC_DATABASE_URL` | `jdbc:postgresql://HOST:DB_PORT/DATABASE?password=PASSWORD&user=USERNAME` | Полный JDBC URL |
| `USERNAME` | *пользователь БД* | Из карточки PostgreSQL |
| `PASSWORD` | *пароль БД* | Из карточки PostgreSQL |
| `DATABASE` | *имя БД* | Имя базы (например, `hexlet_cv_db_xf4t`) |
| `HOST` | *хост БД* | Internal hostname (например, `dpg-xxxxx-a`) |
| `DB_PORT` | `5432` | Порт PostgreSQL |

**Как получить значения:**

- В карточке PostgreSQL на Render откройте **Info**.
- `HOST`, `DATABASE`, `USERNAME`, `PASSWORD`, `DB_PORT` — отдельные поля или из **Internal Database URL**.
- `JDBC_DATABASE_URL` — соберите вручную:  
  `jdbc:postgresql://HOST:DB_PORT/DATABASE?password=PASSWORD&user=USERNAME`  
  либо возьмите Internal Database URL и замените `postgresql://` на `jdbc:postgresql://`, при необходимости добавив `?sslmode=require`.

---

## Шаг 4. Деплой

1. Проверьте, что все переменные окружения сохранены.
2. Нажмите **Create Web Service**.
3. Render соберёт образ по Dockerfile (multi-stage: frontend на Node 20, backend на Gradle/JDK 17, runtime на Eclipse Temurin 24) и запустит контейнер. Первый деплой может занять несколько минут.
4. В логах сервиса убедитесь, что приложение стартовало без ошибок и что оно подключается к PostgreSQL.

После успешного деплоя сервису будет выдан URL вида:  
`https://hexlet-cv.onrender.com` (или ваш **Name**).

---

## Шаг 5. Автодеплой из Git

- При пуше в выбранную ветку (например, `main`) Render по умолчанию запускает новый деплой.
- Отключить можно в настройках сервиса: **Settings** → **Build & Deploy** → **Auto-Deploy** → No.

---

## Опционально: render.yaml (Blueprint)

Можно описать сервис и БД в одном файле и развернуть через **Blueprint**:

1. В корне репозитория создайте `render.yaml` (или `render.yml`).
2. В Dashboard: **New** → **Blueprint** → выберите репозиторий; Render подхватит `render.yaml`.

Пример минимального `render.yaml`:

```yaml
databases:
  - name: hexlet-cv-db
    databaseName: hexlet_cv
    user: hexlet_cv
    plan: free

services:
  - type: web
    name: hexlet-cv
    runtime: docker
    plan: free
    envVars:
      - key: SPRING_PROFILES_ACTIVE
        value: prod
      # JDBC_DATABASE_URL: connectionString даёт postgresql://... — Spring Boot требует jdbc:postgresql://...
      # Добавьте JDBC_DATABASE_URL вручную в Dashboard как Secret (jdbc: + Internal Database URL)
      - key: USERNAME
        fromDatabase:
          name: hexlet-cv-db
          property: user
      - key: PASSWORD
        fromDatabase:
          name: hexlet-cv-db
          property: password
```

> **Примечание:** Render возвращает `connectionString` в формате `postgresql://...`. Spring Boot требует `jdbc:postgresql://...`. При использовании Blueprint добавьте `JDBC_DATABASE_URL` вручную в Dashboard как Secret, указав Internal Database URL с префиксом `jdbc:`.

Схема и имена свойств БД уточняйте в [документации Render](https://render.com/docs). После этого деплой можно выполнять через один Blueprint.

---

## Проверка

1. Откройте URL сервиса в браузере — должна открыться главная страница приложения.
2. Убедитесь, что нет ошибок в **Logs** в панели Render.
3. При проблемах с БД проверьте, что используется **Internal Database URL** и что переменные `USERNAME` и `PASSWORD` совпадают с учётными данными этой базы.

---

## Краткий чеклист

- [ ] Создана PostgreSQL на Render, скопированы URL и учётные данные.
- [ ] Создан Web Service с Runtime = Docker, указан репозиторий и ветка.
- [ ] Добавлены переменные: `SPRING_PROFILES_ACTIVE`, `JDBC_DATABASE_URL`, `USERNAME`, `PASSWORD`, `DATABASE`, `HOST`, `DB_PORT`.
- [ ] Выполнен первый деплой, логи без ошибок, приложение открывается по URL.

После этого деплой на Render.com считается настроенным; дальнейшие обновления — через push в выбранную ветку.
