---
name: Email Registration Flow Design
description: Полная архитектура email регистрации и верификации для iOS
type: design
---

# Email Registration Flow Design

## Обзор

Переделка авторизации в iOS для поддержки email регистрации с верификацией по коду. Пользователи получают доступ к чату, написанию постов и профилю только после верификации email.

## Текущее состояние

### iOS
- Device-based auth с автоматической регистрацией
- Email linking для привязки email к существующему аккаунту
- Старая логика регистрации (LoginView, RegisterView)

### Backend
- `/auth/device` — device auth
- `/auth/link-email` — отправка кода на email (требует Bearer token)
- `/auth/verify-email` — верификация кода (требует Bearer token)
- `/auth/refresh` — обновление access token

## Архитектура решения

### 1. AuthManager (расширение)

**Новые свойства:**
```
@Published private(set) var isEmailVerified: Bool = false
```

**Новые методы:**
```
func setEmailVerified(_ value: Bool)
func saveRegistrationEmail(_ email: String)
func getRegistrationEmail() -> String?
```

**Логика:**
- `isAuthenticated` → есть device bearer token в Keychain
- `isEmailVerified` → флаг, сохраненный в Keychain вместе с token

### 2. AuthViewModel (полная переделка)

**Новый enum для регистрации:**
```swift
enum RegistrationState {
    case idle
    case enteringEmail
    case verifyingEmail
    case success
}
```

**Публичные свойства:**
```
@Published var registrationState: RegistrationState = .idle
@Published var isLoading: Bool = false
@Published var errorMessage: String?
```

**Методы:**
```
func startRegistration() async
func linkEmail(email: String, password: String) async
func verifyEmail(code: String) async
func requestNewCode() async
func cancelRegistration()
```

**Удаляемые методы (legacy):**
- `register(email, password, username)` — используется только device auth
- `login(email, password)` — нет email/password login
- `deviceLogin()` — заменяется на автоматический device auth при старте
- `switchAccount()`
- `listDeviceAccounts()`

### 3. Screen Flow

#### При открытии приложения
1. Проверяем есть ли device token в Keychain
2. Если нет → автоматический device auth (`POST /auth/device`)
3. Сохраняем Bearer token

#### На защищенных экранах (Чат, Посты, Профиль)
```swift
if authManager.isEmailVerified {
    // основной контент
} else {
    authPromptView(
        title: "AI-помощник требует аккаунта",
        button: "Создать аккаунт"
    )
}
```

#### Flow регистрации (sheet/full-screen)
1. **EmailRegistrationView** (новое имя для email linking screen)
   - Ввод: email, password
   - Валидация email формата
   - Кнопка "Продолжить" → `linkEmail(email, password)`
   - На успех → EmailVerificationView
   - На ошибку → показываем errorMessage

2. **EmailVerificationView** (существует, улучшаем)
   - Ввод: 6-значный код
   - Таймер на переотправку кода
   - Кнопка "Подтвердить" → `verifyEmail(code)`
   - Кнопка "Отправить код ещё раз" → `requestNewCode()`
   - На успех → закрываем sheet, возвращаемся на исходный экран
   - На ошибку → показываем errorMessage

#### Закрытие экрана регистрации
- Пользователь может закрыть sheet в любой момент
- `currentEmail` сохраняется в памяти
- При повторном открытии регистрации → начинаем с EmailVerificationView если email уже привязан

### 4. Access Control

**Требуют email верификации:**
- ❌ ChatView — полностью
- ❌ NewPostSheet — не может открыться
- ❌ ProfileView — полностью

**Доступны без верификации:**
- ✅ FeedView — просмотр постов (read-only)
- ✅ Health, Shelters, Pets — все функции
- ✅ HomeView

### 5. Удаляемый код

**Удаляем экраны:**
- `DeviceLoginView.swift`
- `LoginView.swift`
- `RegisterView.swift` (если старая реализация)
- `EmailLinkingPromptView.swift`
- `AuthPromptSheet.swift` (если не используется)

**Упрощаем:**
- `AuthView.swift` — может остаться как контейнер или переделаться

## API интеграция

### Автоматический Device Auth
```
POST /auth/device
Body: { device_id: String }
Response: { token, refreshToken, userId, isNew }
```

### Email Linking
```
POST /auth/link-email
Headers: Authorization: Bearer {token}
Body: { email, password }
Response: { status: "verification_sent" }
Побочный эффект: код отправлен на email
```

### Email Verification
```
POST /auth/verify-email
Headers: Authorization: Bearer {token}
Body: { code }
Response: { status: "ok" }
Побочный эффект: email верифицирован
```

## Error Handling

- 401 Unauthorized → сессия истекла, нужен refresh или новый device auth
- 409 Conflict → email уже используется
- Timeout на кодовое слово → можно переотправить
- Network errors → user-friendly сообщение

## State Persistence

- Device token → Keychain (существует)
- Email verified status → Keychain вместе с token
- Текущий email при регистрации → в памяти (AuthViewModel)
- После перезагрузки приложения → проверяем Keychain

## Testing

- Unit tests для AuthManager (token storage)
- Unit tests для AuthViewModel (state transitions)
- Integration tests для flow: device auth → email linking → verification

---

**Статус:** ✅ Одобрено для реализации
