# Petio API

## 1. Общая информация

| Параметр | Значение |
|----------|----------|
| Base URL | `http://localhost:8080` |
| Префикс | `/v1` |
| Формат | JSON (`Content-Type: application/json`) |
| Авторизация | `Authorization: Bearer <token>` |

**Формат ошибок:**

```json
{"error": "описание ошибки"}
```

**Общие коды ответов:**

| Код | Описание |
|-----|----------|
| 200 | Успех |
| 201 | Создано |
| 204 | Удалено (без тела) |
| 400 | Невалидный запрос |
| 401 | Не авторизован |
| 403 | Доступ запрещен |
| 404 | Не найдено |
| 409 | Конфликт (email уже занят) |
| 413 | Файл слишком большой |
| 422 | Контент отклонен модерацией |
| 500 | Ошибка сервера |
| 503 | Сервис недоступен (S3 не настроен) |

---

## 2. Аутентификация

### POST /v1/auth/device

Вход или авторегистрация по device_id. Если устройство новое -- создается анонимный аккаунт.

- **Auth:** не требуется

**Request:**
```json
{
  "device_id": "AABB-1122-CCDD-3344"
}
```

**Response 200:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "550e8400-e29b-41d4-a716-446655440000...",
  "userId": "d290f1ee-6c54-4b01-90e6-d701748f0851",
  "isNew": true
}
```

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | `device_id` не передан |

---

### POST /v1/auth/register

Регистрация с email и паролем.

- **Auth:** не требуется

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securePass123"
}
```

**Response 200:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "550e8400-e29b-41d4..."
}
```

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Пустой email или password |
| 409 | Email уже зарегистрирован |

---

### POST /v1/auth/login

Вход с email и паролем.

- **Auth:** не требуется

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securePass123"
}
```

**Response 200:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "550e8400-e29b-41d4..."
}
```

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Невалидное тело запроса |
| 401 | Неверный email или пароль |

---

### POST /v1/auth/refresh

Обновить access-токен по refresh-токену. Старый refresh-токен инвалидируется, возвращается новая пара.

- **Auth:** не требуется

**Request:**
```json
{
  "refreshToken": "550e8400-e29b-41d4..."
}
```

**Response 200:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "661f9511-f30c-52e5..."
}
```

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Невалидное тело |
| 401 | Невалидный или истекший refresh-токен |

---

### GET /v1/auth/device/accounts

Список аккаунтов, привязанных к устройству.

- **Auth:** не требуется

**Query параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|:---:|----------|
| device_id | string | да | ID устройства |

**Response 200:**
```json
[
  {
    "userId": "d290f1ee-6c54-4b01-90e6-d701748f0851",
    "email": "user@example.com"
  },
  {
    "userId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  }
]
```

---

### POST /v1/auth/device/switch

Переключиться на другой аккаунт на том же устройстве.

- **Auth:** не требуется

**Request:**
```json
{
  "device_id": "AABB-1122-CCDD-3344",
  "user_id": "d290f1ee-6c54-4b01-90e6-d701748f0851"
}
```

**Response 200:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "550e8400-e29b-41d4..."
}
```

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Не переданы device_id / user_id |
| 403 | Аккаунт не привязан к этому устройству |

---

### POST /v1/auth/link-email

Привязать email к анонимному аккаунту. Отправляет 6-значный код верификации на почту. Email НЕ сохраняется до подтверждения кода через `/auth/verify-email`.

- **Auth:** JWT required

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securePass123"
}
```

**Response 200:**
```json
{
  "status": "verification_sent"
}
```

| Код | Когда |
|-----|-------|
| 200 | Код отправлен |
| 400 | Пустой email или password |
| 401 | Нет токена |
| 409 | Email уже используется другим аккаунтом |

---

### POST /v1/auth/verify-email

Подтвердить email 6-значным кодом из письма. После подтверждения email и пароль привязываются к аккаунту.

- **Auth:** JWT required

**Request:**
```json
{
  "code": "482901"
}
```

**Response 200:**
```json
{
  "status": "ok"
}
```

| Код | Когда |
|-----|-------|
| 200 | Email привязан |
| 400 | Неверный или истекший код (15 минут) |
| 401 | Нет токена |
| 409 | Email уже используется |

---

### POST /v1/auth/forgot-password

Запросить сброс пароля. Отправляет 6-значный код на email. Всегда возвращает 200 (защита от перебора email).

- **Auth:** не требуется

**Request:**
```json
{
  "email": "user@example.com"
}
```

**Response 200:**
```json
{
  "status": "ok"
}
```

---

### POST /v1/auth/reset-password

Сбросить пароль по коду из email.

- **Auth:** не требуется

**Request:**
```json
{
  "email": "user@example.com",
  "code": "482901",
  "new_password": "newSecurePass456"
}
```

**Response 200:**
```json
{
  "status": "ok"
}
```

| Код | Когда |
|-----|-------|
| 200 | Пароль обновлен |
| 400 | Неверный/истекший код или пустой new_password |

---

## 3. Профиль

### GET /v1/profile

Получить профиль текущего пользователя.

- **Auth:** JWT required

**Response 200:**
```json
{
  "name": "Иван",
  "username": "ivan_petlover",
  "avatar": "https://s3.example.com/avatars/uuid.jpg",
  "bio": "Люблю котиков",
  "petsCount": 2,
  "postsCount": 5,
  "joinDate": "2025-03-15T10:00:00Z"
}
```

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 401 | Нет токена |
| 404 | Профиль не найден |

---

### PUT /v1/profile

Обновить профиль. Тексты проходят модерацию.

- **Auth:** JWT required

**Request:**
```json
{
  "name": "Иван",
  "username": "ivan_petlover",
  "avatar": "https://s3.example.com/avatars/uuid.jpg",
  "bio": "Люблю котиков"
}
```

**Response 200:** возвращает обновленный профиль (формат как в GET).

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Невалидное тело |
| 401 | Нет токена |
| 404 | Профиль не найден |
| 422 | Текст отклонен модерацией |

---

## 4. Питомцы

### GET /v1/pets

Список питомцев текущего пользователя.

- **Auth:** JWT required

**Response 200:**
```json
[
  {
    "id": "pet-uuid-1",
    "name": "Барсик",
    "species": "cat",
    "breed": "Мейн-кун",
    "age": 3,
    "weight": 5.2,
    "photo": "https://s3.example.com/pets/uuid.jpg",
    "birthDate": "2022-06-15T00:00:00Z",
    "vaccinations": [
      {
        "id": "vacc-uuid",
        "name": "Бешенство",
        "date": "2024-01-10T00:00:00Z",
        "nextDate": "2025-01-10T00:00:00Z"
      }
    ],
    "features": ["friendly", "indoor"]
  }
]
```

---

### GET /v1/pets/{id}

Получить питомца по ID.

- **Auth:** JWT required

**Response 200:** объект Pet (формат как выше).

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 404 | Питомец не найден |

---

### POST /v1/pets

Создать питомца.

- **Auth:** JWT required

**Request:**
```json
{
  "name": "Барсик",
  "species": "cat",
  "breed": "Мейн-кун",
  "age": 3,
  "weight": 5.2,
  "photo": "https://s3.example.com/pets/uuid.jpg",
  "birthDate": "2022-06-15T00:00:00Z",
  "vaccinations": [],
  "features": ["friendly"]
}
```

**Response 201:** созданный объект Pet с заполненным `id`.

---

### PUT /v1/pets/{id}

Обновить питомца.

- **Auth:** JWT required

**Request:** аналогично POST.

**Response 200:** обновленный объект Pet.

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Невалидное тело |
| 404 | Питомец не найден |

---

### DELETE /v1/pets/{id}

Удалить питомца.

- **Auth:** JWT required

**Response:** 204 No Content.

| Код | Когда |
|-----|-------|
| 204 | Удалено |
| 404 | Питомец не найден |

---

## 5. Вес

Записи веса привязаны к питомцу. Ключ записи -- дата (YYYY-MM-DD).

### GET /v1/pets/{petId}/weight

Список всех записей веса питомца.

- **Auth:** JWT required

**Response 200:**
```json
[
  {
    "date": "2025-03-01T00:00:00Z",
    "weight": 5.2
  },
  {
    "date": "2025-02-01T00:00:00Z",
    "weight": 5.0
  }
]
```

---

### GET /v1/pets/{petId}/weight/{date}

Получить запись веса по дате. Формат даты: `YYYY-MM-DD`.

- **Auth:** JWT required

**Response 200:**
```json
{
  "date": "2025-03-01T00:00:00Z",
  "weight": 5.2
}
```

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Неверный формат даты |
| 404 | Запись не найдена |

---

### POST /v1/pets/{petId}/weight

Добавить запись веса.

- **Auth:** JWT required

**Request:**
```json
{
  "date": "2025-03-01T00:00:00Z",
  "weight": 5.2
}
```

**Response:** 201 Created (без тела).

---

### PUT /v1/pets/{petId}/weight/{date}

Обновить запись веса по дате.

- **Auth:** JWT required

**Request:**
```json
{
  "weight": 5.4
}
```

**Response 200:**
```json
{
  "date": "2025-03-01T00:00:00Z",
  "weight": 5.4
}
```

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Неверный формат даты |
| 404 | Запись не найдена |

---

### DELETE /v1/pets/{petId}/weight/{date}

Удалить запись веса.

- **Auth:** JWT required

**Response:** 204 No Content.

| Код | Когда |
|-----|-------|
| 204 | Удалено |
| 400 | Неверный формат даты |
| 404 | Запись не найдена |

---

## 6. Дневник здоровья

### GET /v1/pets/{petId}/diary

Список записей дневника для питомца.

- **Auth:** JWT required

**Response 200:**
```json
[
  {
    "id": "entry-uuid-1",
    "petId": "pet-uuid-1",
    "date": "2025-03-10T00:00:00Z",
    "note": "Визит к ветеринару, все в порядке"
  }
]
```

---

### POST /v1/pets/{petId}/diary

Создать запись в дневнике.

- **Auth:** JWT required

**Request:**
```json
{
  "date": "2025-03-10T00:00:00Z",
  "note": "Визит к ветеринару, все в порядке"
}
```

**Response 201:**
```json
{
  "id": "entry-uuid-1",
  "petId": "pet-uuid-1",
  "date": "2025-03-10T00:00:00Z",
  "note": "Визит к ветеринару, все в порядке"
}
```

---

### GET /v1/diary/{id}

Получить запись дневника по ID.

- **Auth:** JWT required

**Response 200:** объект HealthDiaryEntry.

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 404 | Запись не найдена |

---

### PUT /v1/diary/{id}

Обновить запись дневника.

- **Auth:** JWT required

**Request:**
```json
{
  "petId": "pet-uuid-1",
  "date": "2025-03-10T00:00:00Z",
  "note": "Обновленная заметка"
}
```

**Response:** 200 OK (без тела).

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Невалидное тело |
| 404 | Запись не найдена |

---

### DELETE /v1/diary/{id}

Удалить запись дневника.

- **Auth:** JWT required

**Response:** 204 No Content.

| Код | Когда |
|-----|-------|
| 204 | Удалено |
| 404 | Запись не найдена |

---

## 7. Напоминания

### GET /v1/reminders

Список напоминаний. Можно фильтровать по питомцу.

- **Auth:** JWT required

**Query параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|:---:|----------|
| petId | string | нет | Фильтр по ID питомца |

**Response 200:**
```json
[
  {
    "id": "rem-uuid-1",
    "petId": "pet-uuid-1",
    "petName": "Барсик",
    "type": "vaccination",
    "title": "Прививка от бешенства",
    "date": "2025-04-01T00:00:00Z",
    "time": "10:00",
    "completed": false
  }
]
```

Допустимые значения `type`: `feeding`, `vaccination`, `deworming`, `grooming`.

---

### GET /v1/reminders/{id}

Получить напоминание по ID.

- **Auth:** JWT required

**Response 200:** объект Reminder.

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 404 | Напоминание не найдено |

---

### POST /v1/reminders

Создать напоминание.

- **Auth:** JWT required

**Request:**
```json
{
  "petId": "pet-uuid-1",
  "petName": "Барсик",
  "type": "vaccination",
  "title": "Прививка от бешенства",
  "date": "2025-04-01T00:00:00Z",
  "time": "10:00",
  "completed": false
}
```

**Response 201:** созданный объект Reminder с `id`.

---

### PUT /v1/reminders/{id}

Обновить напоминание.

- **Auth:** JWT required

**Request:** аналогично POST.

**Response 200:** обновленный объект Reminder.

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Невалидное тело |
| 404 | Напоминание не найдено |

---

### DELETE /v1/reminders/{id}

Удалить напоминание.

- **Auth:** JWT required

**Response:** 204 No Content.

---

## 8. Статьи

### GET /v1/articles

Список всех статей.

- **Auth:** JWT required

**Response 200:**
```json
[
  {
    "id": "art-uuid-1",
    "title": "Как ухаживать за котенком",
    "description": "Подробное руководство для новых владельцев...",
    "category": "уход",
    "image": "https://s3.example.com/articles/img.jpg",
    "petType": "cat",
    "careType": "general",
    "readTime": 5
  }
]
```

---

### GET /v1/articles/{id}

Получить статью по ID.

- **Auth:** JWT required

**Response 200:** объект Article.

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 404 | Статья не найдена |

---

### POST /v1/articles

Создать статью.

- **Auth:** JWT required

**Request:**
```json
{
  "title": "Как ухаживать за котенком",
  "description": "Подробное руководство...",
  "category": "уход",
  "image": "https://s3.example.com/articles/img.jpg",
  "petType": "cat",
  "careType": "general",
  "readTime": 5
}
```

**Response 201:** созданный объект Article с `id`.

---

### PUT /v1/articles/{id}

Обновить статью.

- **Auth:** JWT required

**Request:** аналогично POST.

**Response 200:** обновленный объект Article.

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 404 | Статья не найдена |

---

### DELETE /v1/articles/{id}

Удалить статью.

- **Auth:** JWT required

**Response:** 204 No Content.

---

## 9. Посты

### GET /v1/posts

Список постов с курсорной пагинацией.

- **Auth:** JWT required

**Query параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|:---:|----------|
| limit | int | нет | Количество постов (по умолчанию 20, макс 50) |
| after_id | string | нет | ID поста -- загрузить посты старше этого |
| before_id | string | нет | ID поста -- загрузить посты новее этого |
| club | string | нет | Фильтр по клубу |

**Response 200:**
```json
{
  "posts": [
    {
      "id": "post-uuid-1",
      "author": "ivan_petlover",
      "avatar": "https://s3.example.com/avatars/uuid.jpg",
      "content": "Мой котик сегодня очень активный!",
      "image": "https://s3.example.com/posts/uuid.jpg",
      "likes": 12,
      "comments": [
        {
          "id": "comment-uuid-1",
          "author": "maria",
          "avatar": "https://s3.example.com/avatars/uuid2.jpg",
          "content": "Какой красавец!",
          "timestamp": "2025-03-15T12:30:00Z"
        }
      ],
      "club": "cats",
      "timestamp": "2025-03-15T10:00:00Z",
      "liked": true
    }
  ],
  "has_more": true,
  "has_new": false
}
```

---

### GET /v1/posts/all

Список всех постов (без пагинации, для совместимости).

- **Auth:** JWT required

**Query параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|:---:|----------|
| club | string | нет | Фильтр по клубу |

**Response 200:** массив объектов Post.

---

### GET /v1/posts/{id}

Получить пост по ID.

- **Auth:** JWT required

**Response 200:** объект Post.

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 404 | Пост не найден |

---

### POST /v1/posts

Создать пост. Текст проходит модерацию. Автор и аватар подставляются из профиля.

- **Auth:** JWT required

**Request:**
```json
{
  "content": "Мой котик сегодня очень активный!",
  "image": "https://s3.example.com/posts/uuid.jpg",
  "club": "cats"
}
```

**Response 201:** созданный объект Post с `id`, `author`, `avatar`, `timestamp`.

| Код | Когда |
|-----|-------|
| 201 | Создано |
| 400 | Невалидное тело |
| 422 | Текст отклонен модерацией |

---

### PUT /v1/posts/{id}

Обновить пост. Текст проходит модерацию.

- **Auth:** JWT required

**Request:**
```json
{
  "content": "Обновленный текст поста",
  "image": "https://s3.example.com/posts/uuid.jpg",
  "club": "cats"
}
```

**Response 200:** обновленный объект Post.

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 404 | Пост не найден |
| 422 | Текст отклонен модерацией |

---

### DELETE /v1/posts/{id}

Удалить пост.

- **Auth:** JWT required

**Response:** 204 No Content.

---

### POST /v1/posts/{id}/like

Поставить или убрать лайк.

- **Auth:** JWT required

**Request:**
```json
{
  "liked": true
}
```

**Response:** 200 OK (без тела).

---

### POST /v1/posts/{postId}/comments

Добавить комментарий к посту. Текст проходит модерацию. Автор и аватар подставляются из профиля.

- **Auth:** JWT required

**Request:**
```json
{
  "content": "Какой красавец!"
}
```

**Response 201:**
```json
{
  "id": "comment-uuid-1",
  "author": "maria",
  "avatar": "https://s3.example.com/avatars/uuid2.jpg",
  "content": "Какой красавец!",
  "timestamp": "2025-03-15T12:30:00Z"
}
```

| Код | Когда |
|-----|-------|
| 201 | Создано |
| 400 | Невалидное тело |
| 422 | Текст отклонен модерацией |

---

## 10. Приюты

### GET /v1/shelters

Список всех приютов.

- **Auth:** JWT required

**Response 200:**
```json
[
  {
    "id": "shelter-uuid-1",
    "image": "https://s3.example.com/shelters/img.jpg",
    "type": "cats",
    "name": "Котохаус",
    "description": "Приют для бездомных кошек",
    "websiteUrl": "https://kotohouse.ru"
  }
]
```

---

### GET /v1/shelters/{id}

Получить приют по ID.

- **Auth:** JWT required

**Response 200:** объект Shelter.

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 404 | Приют не найден |

---

### POST /v1/shelters

Создать приют.

- **Auth:** JWT required

**Request:**
```json
{
  "image": "https://s3.example.com/shelters/img.jpg",
  "type": "cats",
  "name": "Котохаус",
  "description": "Приют для бездомных кошек",
  "websiteUrl": "https://kotohouse.ru"
}
```

**Response 201:** созданный объект Shelter с `id`.

---

### PUT /v1/shelters/{id}

Обновить приют.

- **Auth:** JWT required

**Request:** аналогично POST.

**Response 200:** обновленный объект Shelter.

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 404 | Приют не найден |

---

### DELETE /v1/shelters/{id}

Удалить приют.

- **Auth:** JWT required

**Response:** 204 No Content.

---

## 11. Чаты (AI-ассистент)

### GET /v1/chats

Список чатов текущего пользователя.

- **Auth:** JWT required

**Query параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|:---:|----------|
| limit | int | нет | Количество (по умолчанию 20) |
| offset | int | нет | Смещение |

**Response 200:**
```json
[
  {
    "id": "chat-uuid-1",
    "user_id": "user-uuid",
    "title": "Вопрос про питание",
    "created_at": "2025-03-15T10:00:00Z",
    "updated_at": "2025-03-15T10:05:00Z",
    "last_message": {
      "id": "msg-uuid",
      "chat_id": "chat-uuid-1",
      "role": "assistant",
      "content": "Рекомендую корм...",
      "created_at": "2025-03-15T10:05:00Z"
    },
    "stats": {
      "chat_id": "chat-uuid-1",
      "message_count": 4,
      "total_input_tokens": 150,
      "total_output_tokens": 320,
      "total_tokens": 470,
      "last_message_at": "2025-03-15T10:05:00Z"
    }
  }
]
```

---

### POST /v1/chats

Создать новый чат.

- **Auth:** JWT required

**Request (необязательное тело):**
```json
{
  "title": "Вопрос про питание"
}
```

**Response 201:**
```json
{
  "id": "chat-uuid-1",
  "user_id": "user-uuid",
  "title": "Вопрос про питание",
  "created_at": "2025-03-15T10:00:00Z",
  "updated_at": "2025-03-15T10:00:00Z"
}
```

---

### GET /v1/chats/stats

Общая статистика по чатам пользователя.

- **Auth:** JWT required

**Response 200:**
```json
{
  "chat_id": "",
  "message_count": 42,
  "total_input_tokens": 5200,
  "total_output_tokens": 12800,
  "total_tokens": 18000,
  "last_message_at": "2025-03-15T10:05:00Z"
}
```

---

### GET /v1/chats/{id}

Получить чат по ID.

- **Auth:** JWT required

**Response 200:** объект Chat.

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 404 | Чат не найден |

---

### PATCH /v1/chats/{id}

Обновить название чата.

- **Auth:** JWT required

**Request:**
```json
{
  "title": "Новое название"
}
```

**Response:** 200 OK (без тела).

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Невалидное тело |
| 404 | Чат не найден |

---

### DELETE /v1/chats/{id}

Удалить чат.

- **Auth:** JWT required

**Response:** 204 No Content.

| Код | Когда |
|-----|-------|
| 204 | Удалено |
| 404 | Чат не найден |

---

### GET /v1/chats/{id}/messages

Получить историю сообщений чата.

- **Auth:** JWT required

**Query параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|:---:|----------|
| limit | int | нет | Количество (по умолчанию 50) |
| offset | int | нет | Смещение |

**Response 200:**
```json
[
  {
    "id": "msg-uuid-1",
    "chat_id": "chat-uuid-1",
    "role": "user",
    "content": "Чем кормить котенка 3 месяца?",
    "created_at": "2025-03-15T10:00:00Z"
  },
  {
    "id": "msg-uuid-2",
    "chat_id": "chat-uuid-1",
    "role": "assistant",
    "content": "Рекомендую корм для котят...",
    "model_used": "gemma-3",
    "question_type": "nutrition",
    "input_tokens": 75,
    "output_tokens": 160,
    "total_tokens": 235,
    "created_at": "2025-03-15T10:00:05Z"
  }
]
```

---

### POST /v1/chats/{id}/messages

Отправить сообщение в чат. Сервер отправляет текст AI-модели и возвращает ответ ассистента.

- **Auth:** JWT required

**Request:**
```json
{
  "text": "Чем кормить котенка 3 месяца?"
}
```

**Response 200:** объект ChatMessage (ответ ассистента).

```json
{
  "id": "msg-uuid-2",
  "chat_id": "chat-uuid-1",
  "role": "assistant",
  "content": "Рекомендую корм для котят...",
  "model_used": "gemma-3",
  "question_type": "nutrition",
  "input_tokens": 75,
  "output_tokens": 160,
  "total_tokens": 235,
  "created_at": "2025-03-15T10:00:05Z"
}
```

| Код | Когда |
|-----|-------|
| 200 | Успех |
| 400 | Пустой `text` или невалидное тело |

---

## 12. Загрузка файлов

Все эндпоинты принимают `multipart/form-data` с полем `file`. Максимальный размер -- 10 MB. Допустимые типы: JPEG, PNG, GIF, WebP. Изображения проходят ML-модерацию.

### POST /v1/upload/pet-photo

Загрузить фото питомца.

- **Auth:** JWT required
- **Content-Type:** `multipart/form-data`

**Request:** поле `file` с изображением.

**Response 201:**
```json
{
  "url": "https://s3.example.com/pets/user-uuid/random-uuid.jpg"
}
```

| Код | Когда |
|-----|-------|
| 201 | Загружено |
| 400 | Нет файла, неподдерживаемый формат, пустой файл |
| 401 | Нет токена |
| 413 | Файл больше 10 MB |
| 422 | Изображение отклонено модерацией |
| 503 | S3 не настроен |

---

### POST /v1/upload/post-image

Загрузить картинку к посту. Формат аналогичен `pet-photo`.

- **Auth:** JWT required
- **Content-Type:** `multipart/form-data`

**Response 201:**
```json
{
  "url": "https://s3.example.com/posts/user-uuid/random-uuid.jpg"
}
```

---

### POST /v1/upload/avatar

Загрузить аватар пользователя. Формат аналогичен `pet-photo`.

- **Auth:** JWT required
- **Content-Type:** `multipart/form-data`

**Response 201:**
```json
{
  "url": "https://s3.example.com/avatars/user-uuid/random-uuid.jpg"
}
```

---

## Служебные эндпоинты

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/health` | Проверка здоровья. Возвращает `{"status":"ok"}` |
| GET | `/metrics` | Prometheus-метрики |
| GET | `/swagger/*` | Swagger UI |
