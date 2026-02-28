# Design: Auth Screens + Network Layer

**Date:** 2026-02-28
**Status:** Approved

## Overview

Add login/registration screens to the iOS client and replace mock data with real API requests by implementing a proper network layer connected to the Go backend.

## Decisions

- JWT token stored in iOS **Keychain** (native `Security` framework, no third-party libs)
- Base URL: `http://localhost:8080/v1` (dev), configurable later
- Auth screens follow existing **PetCareTheme** (green palette, rounded cards, SF Pro)
- After successful **registration** → auto-login (token is returned in `/auth/register` response)
- Network layer: **Approach A** — plain `URLSession` implementing existing `APIClientProtocol`

---

## Section 1: Auth Screens

### Files
- `Features/Auth/AuthView.swift` — root container with `NavigationStack`
- `Features/Auth/LoginView.swift` — login form
- `Features/Auth/RegisterView.swift` — registration form
- `Features/Auth/AuthViewModel.swift` — shared `ObservableObject` for auth logic

### LoginView
- Logo/icon at top
- Fields: Email (`TextField`), Password (`SecureField`)
- "Войти" button (`PetCareButton`)
- Link "Нет аккаунта? Зарегистрироваться" → `RegisterView`
- Error message displayed below button

### RegisterView
- Fields: Name, Email, Password, Confirm Password
- "Зарегистрироваться" button (`PetCareButton`)
- Link "Уже есть аккаунт? Войти" → back to `LoginView`
- On success → auto-login via token from response

### AuthViewModel
```swift
class AuthViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func login(email: String, password: String) async
    func register(name: String, email: String, password: String) async
}
```

---

## Section 2: AuthManager + Keychain

### File
- `Core/Auth/AuthManager.swift`

```swift
class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool

    func saveToken(_ token: String)  // → Keychain
    func getToken() -> String?       // ← Keychain
    func deleteToken()               // logout
}
```

- Uses native `Security` framework (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`)
- `isAuthenticated` derived from token presence in Keychain
- Injected into `AppState` and `HTTPAPIClient` as dependency via `@EnvironmentObject`

### App Entry Flow
```
App start
  ↓
AuthManager.isAuthenticated?
  ├─ false → AuthView (Login/Register)
  └─ true  → AppTabView (main app)
```

`ContentView` observes `AuthManager.isAuthenticated` and switches views accordingly.
Logout: `AuthManager.deleteToken()` → `isAuthenticated = false` → SwiftUI switches to `AuthView`.

---

## Section 3: HTTPAPIClient

### File
- `Core/Network/HTTPAPIClient.swift`

```swift
class HTTPAPIClient: APIClientProtocol {
    private let baseURL = "http://localhost:8080/v1"
    private let authManager: AuthManager

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}
```

### Request Pipeline
1. Build `URLRequest` from `Endpoint` (path, HTTP method, JSON body)
2. Attach `Authorization: Bearer <token>` from `AuthManager.getToken()`
3. Execute `URLSession.shared.data(for:)`
4. On HTTP 401 → `authManager.deleteToken()` (auto-logout)
5. Decode response with `JSONDecoder` (snake_case → camelCase via `keyDecodingStrategy`)
6. Throw typed `APIError` on failure

### AppState Changes
- Receives `HTTPAPIClient` in production (injected at app startup)
- `MockAPIClient` retained for unit tests only
- Mock-fallback removed from `AppState` load methods — errors surface to user via error state

### AuthViewModel integration
```swift
func login(email: String, password: String) async {
    // POST /auth/login → token → authManager.saveToken(token)
}

func register(name: String, email: String, password: String) async {
    // POST /auth/register → token → authManager.saveToken(token)
}
```

---

## Backend API Reference

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/login` | No | Login → JWT token |
| POST | `/auth/register` | No | Register → JWT token |
| GET | `/pets` | Bearer | List user's pets |
| POST | `/pets` | Bearer | Create pet |
| GET | `/pets/{id}` | Bearer | Get pet |
| PUT | `/pets/{id}` | Bearer | Update pet |
| DELETE | `/pets/{id}` | Bearer | Delete pet |
| GET | `/pets/{petId}/weight` | Bearer | Weight history |
| POST | `/pets/{petId}/weight` | Bearer | Add weight record |
| GET | `/pets/{petId}/diary` | Bearer | Health diary entries |
| POST | `/pets/{petId}/diary` | Bearer | Add diary entry |
| GET | `/reminders` | Bearer | List reminders |
| POST | `/reminders` | Bearer | Create reminder |
| GET | `/articles` | Bearer | List articles |
| GET | `/posts` | Bearer | List posts |
| POST | `/posts/{id}/like` | Bearer | Like/unlike post |
| POST | `/posts/{postId}/comments` | Bearer | Add comment |
| POST | `/chat/send` | Bearer | AI chat |
| GET | `/profile` | Bearer | Get profile |
| PUT | `/profile` | Bearer | Update profile |
| POST | `/upload/pet-photo` | Bearer | Upload pet photo |

---

## File Structure (New Files)

```
Petio-ios/Petio/
├── Core/
│   ├── Auth/
│   │   └── AuthManager.swift          # NEW
│   └── Network/
│       └── HTTPAPIClient.swift        # NEW
└── Features/
    └── Auth/
        ├── AuthView.swift             # NEW
        ├── LoginView.swift            # NEW
        ├── RegisterView.swift         # NEW
        └── AuthViewModel.swift        # NEW
```

## Modified Files

- `ContentView.swift` — auth gate based on `AuthManager.isAuthenticated`
- `PetioApp.swift` — inject `AuthManager` and `HTTPAPIClient` into environment
- `AppState.swift` — receive `HTTPAPIClient`, remove mock fallbacks
