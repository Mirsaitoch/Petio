# iOS Auth система — Device-based логин + Email linking

> **Для реализации:** используй writing-plans skill для создания пошагового плана

**Дата:** 2026-04-24
**Статус:** Дизайн утвержден
**Приоритет:** P0 (блокирует другую функциональность)

---

## Обзор

Переход с простой email/password регистрации на **device-based auth** с опциональной email привязкой:
- Первый запуск: автоматический device login (анонимный аккаунт)
- Опционально: привязать email+пароль для постоянного аккаунта
- Автоматический refresh токенов при 401 ошибке
- Поддержка нескольких аккаунтов на одном device

---

## 1. Компоненты и данные

### 1.1 DeviceManager (новый)
**Назначение:** Управление device_id (уникальный для устройства)

**Функции:**
- `getDeviceID() -> String` — получить/создать device_id
- Device_id хранится в Keychain (перживает переустановку приложения на том же device)
- Format: UUID (v4)

**Keychain ключ:** `com.petio.app.device_id`

### 1.2 AuthManager (обновить)
**Текущее состояние:** хранит только access token

**Обновления:**
- Добавить storage для `refreshToken`
- Добавить storage для `userID`
- Добавить storage для `userEmail` (опционально, если привязан)
- Добавить `isAuthenticated` логику (token должен быть)

**Keychain ключи:**
```
- com.petio.app.token (access token)
- com.petio.app.refreshToken (refresh token)
- com.petio.app.userId
- com.petio.app.userEmail (опционально)
```

### 1.3 AuthViewModel (переписать)
**Удалить:**
- Прямые HTTP запросы (использовать новую структуру)
- Логика email/password регистрации

**Добавить методы:**
```swift
func deviceLogin() async
func listDeviceAccounts() async -> [AccountInfo]
func switchAccount(userId: String) async
func linkEmail(email: String, password: String) async
func verifyEmail(code: String) async
```

**Состояние (@Published):**
```swift
@Published var isAuthenticated: Bool
@Published var isLoading: Bool
@Published var errorMessage: String?
@Published var deviceAccounts: [AccountInfo]
@Published var currentEmail: String?
@Published var showEmailLinking: Bool
```

**Структуры:**
```swift
struct AccountInfo {
    let userId: String
    let email: String?  // nil для анонимных
    let isCurrentAccount: Bool
}
```

### 1.4 HTTPAPIClient (обновить)
**Добавить автоматический refresh логику:**
- Перехватить 401 ошибки в `perform<T>()` методе
- При 401:
  1. Попытаться обновить token через POST /v1/auth/refresh
  2. Сохранить новые token + refreshToken
  3. Повторить исходный запрос
  4. Если refresh fail (401 на refresh) → deleteToken() + выход в auth экран

**Код логики:**
```swift
if http.statusCode == 401 {
    if let newToken = try? await refreshAccessToken() {
        // Повторить запрос с новым токеном
    } else {
        authManager.deleteToken()
        // Show auth screen
    }
}
```

---

## 2. API Endpoints (Backend)

### 2.1 Device Login
```
POST /v1/auth/device
{
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}

Response 200:
{
  "token": "eyJhbGc...",
  "refreshToken": "uuid-uuid-uuid",
  "userId": "user-123",
  "isNew": true
}
```

### 2.2 List Device Accounts
```
GET /v1/auth/device/accounts?device_id=550e8400...

Response 200:
[
  {
    "userId": "user-123",
    "email": null,
    "isCurrentAccount": true
  },
  {
    "userId": "user-456",
    "email": "test@example.com",
    "isCurrentAccount": false
  }
]
```

### 2.3 Switch Account
```
POST /v1/auth/device/switch
{
  "device_id": "550e8400...",
  "user_id": "user-456"
}

Response 200:
{
  "token": "eyJhbGc...",
  "refreshToken": "uuid-uuid-uuid"
}
```

### 2.4 Link Email
```
POST /v1/auth/link-email (JWT required)
{
  "email": "user@example.com",
  "password": "securepassword"
}

Response 200:
{
  "status": "verification_sent"
}
```

### 2.5 Verify Email
```
POST /v1/auth/verify-email (JWT required)
{
  "code": "123456"
}

Response 200:
{
  "status": "ok"
}
```

### 2.6 Refresh Token
```
POST /v1/auth/refresh
{
  "refreshToken": "uuid-uuid-uuid"
}

Response 200:
{
  "token": "eyJhbGc...",
  "refreshToken": "uuid-uuid-uuid"
}
```

---

## 3. UI Flow

### 3.1 Splashscreen/Загрузка (AppContainer)
1. Проверить наличие device_id в Keychain
2. Если нет token → показать DeviceLoginView
3. Если есть token → проверить его валидность
4. Показать основной экран

### 3.2 DeviceLoginView (новый)
**Состояние:** Загрузка с анимацией
```
- Текст: "Один момент, настраиваем ваш аккаунт..."
- Визуально: loader
- После успеха автоматически переходит дальше
```

**На фон:**
```swift
.onAppear {
    await authViewModel.deviceLogin()
}
```

### 3.3 После Device Login
- Если `isNew == true` → EmailLinkingPromptView
- Если `isNew == false` → основной экран

### 3.4 EmailLinkingPromptView (новый)
```
Заголовок: "Защитить аккаунт"
Описание: "Привяжите email и пароль для безопасного доступа на других устройствах"

[Поле Email]
[Поле Password]
[Поле Confirm Password]

[Button "Продолжить"]
[Button "Пропустить"]
```

На нажатие "Продолжить":
1. POST /v1/auth/link-email
2. Показать EmailVerificationView

### 3.5 EmailVerificationView (новый)
```
Заголовок: "Подтвердите email"
Описание: "Мы отправили код на user@example.com"

[6-значный ввод кода]

[Button "Подтвердить"]
[Button "Отправить код заново"]
```

На нажатие "Подтвердить":
1. POST /v1/auth/verify-email
2. Показать success + переход на основной экран

### 3.6 Выход из аккаунта
```swift
authManager.deleteToken()
authManager.refreshToken = nil
authViewModel.isAuthenticated = false
// Show DeviceLoginView (deviceLogin будет создан новый аккаунт OR выберет существующий)
```

---

## 4. Обработка ошибок

### 4.1 Во время device login
- **Network error** → показать retry button
- **Server error (5xx)** → показать "Сервер недоступен, повторите позже"
- **Bad device_id** → пересоздать device_id и retry

### 4.2 Во время email linking
- **Email уже используется** → 409 Conflict → показать ошибку, try другой email
- **Network error** → retry
- **Verification code expired** → показать "Код истек, запросите новый"

### 4.3 Во время refresh token
- **Refresh fail (401)** → token невалидный, выход на DeviceLoginView
- **Network error** → queue запрос, retry при восстановлении сети

---

## 5. Тестирование

### Unit тесты
- DeviceManager: генерирование/сохранение device_id
- AuthManager: сохранение/загрузка token + refreshToken
- AuthViewModel: deviceLogin, linkEmail, verifyEmail
- HTTPAPIClient: 401 handling, refresh logic

### Integration тесты
- Полный flow: device login → email linking → основной экран
- Multi-account: switch между аккаунтами
- Token refresh: запрос получает 401 → refresh → retry

### Manual тесты
- Device login работает быстро (< 2 сек)
- Email verification code приходит в письме
- Переключение между аккаунтами на одном device
- Выход + новый device login создает новый аккаунт
- 401 обработка: приложение прозрачно refresh токен без видимых задержек

---

## 6. Миграция старых пользователей

**Текущая ситуация:** iOS приложение сейчас может быть у пользователей со старой email/password системой.

**План миграции:**
1. Если в Keychain есть старый token → показать диалог "Требуется обновление"
2. Предложить переход на device-based (требует перелогина)
3. Удалить старый token, начать с device login
4. Опционально: восстановить email привязку если пользователь помнит пароль

---

## 7. Файлы для создания/изменения

| Файл | Тип | Назначение |
|------|-----|-----------|
| `Core/Device/DeviceManager.swift` | **Create** | Управление device_id |
| `Core/Auth/AuthManager.swift` | **Update** | Добавить refreshToken storage |
| `Features/Auth/AuthViewModel.swift` | **Update** | Новая логика device + email linking |
| `Core/Network/HTTPAPIClient.swift` | **Update** | Refresh token interceptor |
| `Features/Auth/DeviceLoginView.swift` | **Create** | Splashscreen device login |
| `Features/Auth/EmailLinkingPromptView.swift` | **Create** | Email linking form |
| `Features/Auth/EmailVerificationView.swift` | **Create** | Email verification code |
| `PetioTests/AuthTests.swift` | **Update** | Tests для новой auth системы |

---

## Успешное завершение

✅ Device-based login работает (device_id → token)
✅ Email linking работает (опциональная привязка)
✅ Refresh token работает автоматически при 401
✅ Multi-account поддерживается (список, переключение)
✅ UI плавный и интуитивный
✅ Обработка всех ошибок (network, timeout, invalid code)
✅ Тесты покрывают критические пути
✅ Старые пользователи мигрировали (если были)
