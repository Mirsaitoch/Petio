# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Обзор проекта

Petio — монорепозиторий для социальной сети по уходу за питомцами. Содержит iOS-приложение, Go-бэкенд, ML-сервис модерации контента и инфраструктуру мониторинга.

## Архитектура

```
Petio-Mono/
├── Petio-ios/              # iOS-приложение (SwiftUI, MVVM)
├── backend/                # REST API (Go, Chi, PostgreSQL)
├── moderation_service/     # ML-модерация контента (FastAPI, Triton)
├── triton/                 # ONNX-модели для инференса (NVIDIA Triton)
├── Pet Care Mobile App Design/  # Дизайн-система (React, Radix UI)
├── grafana/                # Дашборды Grafana
├── docker-compose.yml      # Оркестрация всех сервисов
└── docs/                   # Спецификации и планы
```

**Поток данных:** iOS → Backend API → PostgreSQL. Пользовательский контент (посты, изображения) проходит через Moderation Service → Triton (gRPC) для ML-проверки (NSFW, токсичность, CLIP).

## Команды

### Backend (Go)

```bash
# Запуск сервера
cd backend && go run ./cmd/server

# Тесты (требуется PostgreSQL)
DATABASE_URL="postgres://postgres:postgres@localhost:5432/petio_test?sslmode=disable" go test ./tests/ -tags=integration

# Unit-тесты
cd backend && go test ./clients/... ./internal/service/...

# Линтер (используется в CI)
cd backend && golangci-lint run

# Генерация Swagger
cd backend && swag init -g cmd/server/main.go
```

### iOS (Xcode)

```bash
# Сборка
cd Petio-ios && xcodebuild -project Petio.xcodeproj -scheme Petio -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' build

# Тесты
cd Petio-ios && xcodebuild -project Petio.xcodeproj -scheme Petio -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' test
```

### Docker (полный стек)

```bash
docker-compose up -d --build          # Все сервисы
docker-compose up -d postgres backend  # Только БД + бэкенд
```

## Backend (Go)

- **Точка входа:** `backend/cmd/server/main.go`
- **Роутер:** Chi v5 (`internal/transport/http/router.go`)
- **Без ORM** — чистый SQL через `database/sql` + `lib/pq`
- **Миграции:** встроенные через `//go:embed`, авто-запуск при старте (`internal/migrations/`)
- **Конфигурация:** через `.env` файл или переменные окружения (шаблон: `backend/.env.example`)
- **Репозитории:** `internal/repository/postgres/*.go` — по файлу на сущность
- **Хендлеры:** `internal/transport/http/handlers/*.go` — по файлу на домен
- **Внешние клиенты:** `backend/clients/` — S3 (Yandex Object Storage), YandexAI, Moderation, KServe
- **Аутентификация:** JWT (HS256, 7 дней) + device-based auth для мобильных + refresh tokens
- **Метрики:** Prometheus (`internal/metrics/`)
- **Логирование:** Zap (JSON в prod, human-readable в dev)

## iOS (SwiftUI)

- **Точка входа:** `Petio-ios/Petio/PetioApp.swift`
- **Архитектура:** MVVM с централизованным `AppState` как единый источник правды
- **DI:** `AppContainer` создаётся при запуске, пробрасывает зависимости через `@EnvironmentObject`
- **Без внешних зависимостей** — чистый Swift/SwiftUI
- **Сеть:** `Core/Network/HTTPAPIClient.swift` — URLSession, автообновление JWT при 401
- **Хранение:** трёхуровневое — Keychain (токены) → FileManager JSON (данные) → UserDefaults (кэш)
- **Offline:** `NetworkMonitor` + очередь синхронизации при восстановлении связи
- **Дизайн-система:** `Design/PetCareTheme.swift` — палитра цветов и типографика
- **Фичи:** `Features/` — Auth, Home, Pets, Health, Feed, Chat, Profile, Shelters
- **Навигация:** таб-бар (`Navigation/AppTabView.swift`) + роуты (`AppRoute.swift`)

## Moderation Service (Python)

- **FastAPI** приложение (`moderation_service/main.py`)
- **Эндпоинты:** `POST /texts_scores` (токсичность), `POST /images_scores` (NSFW + CLIP)
- **Решения:** allow / review / block с порогами в `moderation.py`
- **Triton:** gRPC-клиент для инференса 4 ONNX-моделей (nsfw, clip_vision, clip_text, text_toxicity)

## CI/CD

- **Backend** (`.github/workflows/ci.yml`): lint → test (с PostgreSQL) → build. Go 1.23.0
- **iOS** (`.github/workflows/ios-ci.yml`): build + test на iPhone 16 Simulator. Xcode 16.3

## Правила веток

Описаны в `BRANCHING.md`. Префиксы: `feature/`, `fix/`, `refactor/`, `docs/`, `chore/`, `release/`, `hotfix/`. Коммиты в формате conventional commits: `feat(scope):`, `fix(scope):`.

## API

Полная документация: `docs/API.md`. Swagger UI доступен на `/swagger/index.html` при запущенном бэкенде.
