# Интеграция нового API хоста и реализация пагинации постов

**Дата:** 2026-04-23
**Статус:** Дизайн утвержден
**Подход:** ViewModel для управления состоянием пагинации + Infinite scroll

---

## Обзор

Миграция iOS приложения на новый хост API (`http://158.160.235.224/v1`) с обновлением лоада постов на cursor-based пагинацию и реализацией infinite scroll в ленте.

---

## 1. Конфигурация API и изменения базового URL

### Текущее состояние
```swift
static var baseURL: URL? { URL(string: "http://localhost:8080/v1") }
```

### Требуемое изменение
Обновить `Endpoints.baseURL` и инициализацию `HTTPAPIClient` на:
```swift
static var baseURL: URL? { URL(string: "http://158.160.235.224/v1") }
```

Также обновить дефолтное значение в `HTTPAPIClient.init()`:
```swift
init(authManager: AuthManager, baseURL: String = "http://158.160.235.224/v1")
```

---

## 2. Модели данных

### PostsResponse — новая модель
Добавить в `Models.swift`:

```swift
struct PostsResponse: Decodable {
    let posts: [Post]
    let hasMore: Bool    // есть ли еще старых постов (при скролле вниз)
    let hasNew: Bool     // есть ли новые посты сверху (при pull-to-refresh)

    enum CodingKeys: String, CodingKey {
        case posts
        case hasMore = "has_more"
        case hasNew = "has_new"
    }
}
```

**Существующая модель `Post`** остается без изменений.

---

## 3. API Client изменения

### APIClientProtocol
Обновить сигнатуру `fetchPosts`:

```swift
func fetchPosts(
    club: String?,
    limit: Int = 20,
    afterID: String?,      // ID для загрузки старых постов
    beforeID: String?      // ID для загрузки новых постов
) async throws -> PostsResponse
```

### HTTPAPIClient реализация
- Построить query параметры из `limit`, `afterID`, `beforeID`, `club`
- Использовать существующий `makeRequest(path:method:queryItems:body:)`
- Декодировать результат в `PostsResponse`
- Логирование остается (для отладки)

---

## 4. FeedViewModel (новый файл)

**Путь:** `Petio-ios/Petio/Features/Feed/FeedViewModel.swift`

Управляет полным состоянием ленты:

```swift
@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedClub = "Все"

    // Состояние пагинации
    @Published var hasMore = false
    @Published var hasNew = false
    private var lastPostID: String?
    private var firstPostID: String?

    private let apiClient: APIClientProtocol
    private let limit = 20

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    // Загрузить первую страницу постов
    func loadInitial() async { }

    // Загрузить старые посты (infinite scroll вниз)
    func loadMore() async { }

    // Обновить новые посты (pull-to-refresh)
    func refresh() async { }

    // Переключение клуба
    func selectClub(_ club: String) { }
}
```

### Логика состояния
- `loadInitial()`: загружает первые `limit` постов без `afterID`/`beforeID`
- `loadMore()`: загружает следующие посты через `afterID = lastPostID`
- `refresh()`: загружает новые посты через `beforeID = firstPostID`
- `selectedClub` изменение: сбрасывает состояние и вызывает `loadInitial()`

---

## 5. FeedView изменения

### Состояние и инициализация
- Добавить `@StateObject var viewModel: FeedViewModel`
- Инициализировать в `AppContainer` и передавать через `@EnvironmentObject`

### Pull-to-refresh
```swift
.refreshable {
    await viewModel.refresh()
}
```

### Infinite scroll триггер
Отслеживать позицию скролла — когда пользователь приближается к концу списка (последние 3 поста):
```swift
if isNearBottom && !viewModel.isLoading && viewModel.hasMore {
    Task { await viewModel.loadMore() }
}
```

Реализация через:
- `ScrollViewReader` для отслеживания видимых элементов
- или `GeometryReader` для определения прогресса скролла
- или простое отслеживание через `onAppear` последнего элемента списка

### Отображение состояния
- **Начальная загрузка:** показать skeleton/spinner вместо пустого списка
- **Ошибка загрузки:** сохранить текущие посты, показать сообщение об ошибке
- **Загрузка новых постов:** spinner внизу списка
- **Нет больше постов:** удалить spinner, если `!hasMore`

### Структура UI
```
VStack {
    header
    ChipGroup(clubs)

    if viewModel.isLoading && viewModel.posts.isEmpty {
        // Skeleton loader
    } else if viewModel.error != nil && viewModel.posts.isEmpty {
        // Error view
    } else {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.posts) { post in
                    PostCard(post: post)
                        .onAppear {
                            // Триггер infinite scroll
                            if isLastPost(post) {
                                await viewModel.loadMore()
                            }
                        }
                }

                // Loading indicator при загрузке дополнительных постов
                if viewModel.isLoading && !viewModel.posts.isEmpty {
                    ProgressView()
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}
.onAppear { await viewModel.loadInitial() }
```

---

## 6. Детали реализации

### Фильтр по клубам
- При изменении `selectedClub`: сбросить `posts`, `lastPostID`, `firstPostID`
- Вызвать `loadInitial()` с новым `club`

### Обработка ошибок
- Если `loadMore()` упадет: сохранить текущие посты, показать alert или inline ошибку
- Если `refresh()` упадет: показать alert, посты остаются в списке
- Повтор загрузки: retry button в error view

### Производительность
- Limit 20 постов по умолчанию (совпадает с бэком)
- `LazyVStack` вместо обычного `VStack` для оптимизации рендеринга
- Кеширование постов в памяти (app.posts остается как источник истины для редактирования)

### Сортировка постов
- `newestFirst` флаг остается в `FeedView`
- Сортировка локально после получения постов из API
- API возвращает посты в нужном порядке (новые сверху), но сохраняем гибкость

---

## 7. Файлы для изменения

| Файл | Тип | Изменения |
|------|-----|-----------|
| `Endpoints.swift` | Update | Изменить `baseURL` на новый хост |
| `HTTPAPIClient.swift` | Update | Обновить `init` параметр baseURL и `fetchPosts` реализацию |
| `APIClient.swift` | Update | Изменить сигнатуру `fetchPosts` для пагинации |
| `Models.swift` | Create | Добавить `PostsResponse` |
| `FeedViewModel.swift` | Create | Новый файл с ViewModel логикой |
| `FeedView.swift` | Update | Использовать ViewModel, добавить infinite scroll и pull-to-refresh |
| `AppContainer.swift` | Update | Инициализировать `FeedViewModel` |

---

## 8. Тестирование

### Unit тесты
- `FeedViewModel.loadInitial()` — первая загрузка, `hasMore = true`
- `FeedViewModel.loadMore()` — загрузка с `afterID`, добавление новых постов
- `FeedViewModel.refresh()` — загрузка новых с `beforeID`
- Фильтр по клубам — сброс состояния

### Integration тесты
- Полный цикл: загрузка → infinite scroll → новые посты
- Обработка ошибок сети
- Переключение клубов

### Manual тесты
- Infinite scroll работает плавно
- Pull-to-refresh срабатывает
- Нет дублирования постов
- Фильтр по клубам работает корректно

---

## 9. Миграция и обратная совместимость

- Старый endpoint `/posts/all` (без пагинации) остается на бэке для совместимости
- iOS полностью переходит на paginated endpoint (`GET /v1/posts`)
- Версионирование API не требуется (изменения внутри v1)

---

## Успешное завершение

✅ iOS приложение использует новый хост
✅ Все посты загружаются с пагинацией (cursor-based)
✅ Infinite scroll работает без задержек
✅ Pull-to-refresh обновляет новые посты
✅ Фильтр по клубам работает с новой пагинацией
✅ Тесты покрывают все сценарии
