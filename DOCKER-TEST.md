# Запуск и тест API через Docker Compose

## Запуск

Из корня репозитория:

```bash
docker-compose up -d --build
```

Поднимаются: **PostgreSQL** (5432) и **приложение** (8080).

Проверка логов:

```bash
docker-compose logs -f app
```

## Тест ручек

### Swagger UI (удобнее всего)

Откройте в браузере: **http://localhost:8080/swagger/index.html**

1. Вызовите `POST /v1/auth/register` с телом `{"email":"test@example.com","password":"password123"}`.
2. Скопируйте из ответа `token`.
3. Нажмите **Authorize**, вставьте `Bearer <token>` (или только токен, если интерфейс подставляет Bearer сам).
4. Дергайте любые ручки из Swagger.

### Ручки через curl

Получить токен (регистрация или логин):

```bash
# Linux / macOS / Git Bash
curl -X POST http://localhost:8080/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

**Windows (PowerShell):** удобнее передать JSON из файла, иначе кавычки экранируются не так:
```powershell
curl.exe -s -X POST http://localhost:8080/v1/auth/register -H "Content-Type: application/json" -d "@backend/scripts/register-body.json"
```
Скопируйте `token` из ответа и подставьте в заголовок ниже.

Подставить `TOKEN` из ответа и вызвать, например:

```bash
# Список питомцев
curl -s http://localhost:8080/v1/pets -H "Authorization: Bearer TOKEN"

# Создать питомца
curl -s -X POST http://localhost:8080/v1/pets \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Барсик\",\"species\":\"cat\",\"breed\":\"дворовый\",\"age\":\"2\",\"weight\":4.5,\"birth_date\":\"2022-01-15\"}"

# Чат
curl -s -X POST http://localhost:8080/v1/chat/send \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"корм\"}"
```

### Скрипт (Linux / macOS / Git Bash)

```bash
cd backend
sh scripts/test-api.sh
```

## Тест загрузки в S3 (Yandex Object Storage)

Чтобы загрузка фото работала, настройте в `.env` или в `environment` приложения переменные S3 (Yandex Object Storage): `S3_BUCKET`, `S3_ENDPOINT`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (см. `backend/.env.example`).

После авторизации в Swagger:

1. **POST /v1/upload/pet-photo** — в форме выберите файл (изображение), отправьте. В ответе будет `url` на файл в хранилище.

Через curl (подставьте `TOKEN`):

```bash
curl -X POST http://localhost:8080/v1/upload/pet-photo \
  -H "Authorization: Bearer TOKEN" \
  -F "file=@/path/to/photo.jpg"
```

## Остановка

```bash
docker-compose down
```

С данными (volumes): `docker-compose down -v`.
