# Petio (Pet Care) — архитектура и вывод о работе

## Структура проекта (копия Pet Care Mobile App Design на SwiftUI)

### 1. Дизайн-компоненты (`Design/`)

- **PetCareTheme** — цвета и общие стили (primary, background, card, border, muted).
- **PetCareButton** — `PetCarePrimaryButton`, `PetCareIconButton`, `PetCareDashedButton`.
- **PetCareCard** — `PetCareCard`, `PetCareInfoCard`, `PetCareReminderRow`.
- **PetCareHeader** — `PetCareGradientHeader`, `PetCareBackHeader`, `PetCareSectionHeader`.
- **AvatarView** / **CircleAvatarView** — аватар по URL с плейсхолдером.
- **IconBadge** — иконка в цветном бейдже (типы напоминаний).
- **SegmentedTabs** / **ChipGroup** — сегменты и горизонтальные чипы.
- **BottomSheet** — модальное окно снизу.

Компоненты не содержат бизнес-логики, только UI и приём действий через замыкания.

---

### 2. Навигация (`Navigation/`)

- **AppRoute** — enum маршрутов: `.pets`, `.petDetail(String)`, `.health`, `.feed`, `.chat`.
- **AppTabView** — нижняя панель табов (Главная, Здоровье, Лента, Профиль) и плавающая кнопка чата.
- Экраны открываются через `NavigationStack(path:)` и `navigationDestination(for: AppRoute.self)` (Home, Profile), а также через `fullScreenCover` (чат с таба).

Навигация централизована в `AppRoute`; переходы выполняются через `path.append(...)` или `NavigationLink(value:)`.

---

### 3. Бизнес-логика (`Services/`)

- **AppState** (ObservableObject):
  - Хранит все данные приложения: `pets`, `reminders`, `weightHistory`, `diary`, `articles`, `posts`, `chatMessages`, `user`, `selectedPetId`.
  - Загрузка: `loadAll()`, `loadPets()`, `loadReminders()`, и т.д. — вызывают API и обновляют состояние.
  - Мутации: `addPet`, `updatePet`, `deletePet`, `toggleReminder`, `addReminder`, `addWeightRecord`, `addDiaryEntry`, `togglePostLike`, `addComment`, `addPost`, `sendChatMessage`, `updateProfile`.
  - Производные данные: `selectedPet`, `todayReminders()`, `upcomingReminders()`, `reminders(forPetId:typeFilter:)`, `diary(forPetId:)`, `weightRecords(forPetId:)`.

Вся работа с данными идёт через `AppState`; экраны только читают `@EnvironmentObject var app: AppState` и вызывают методы/свойства.

---

### 4. Сетевой слой (`Core/Network/`)

- **APIClient** — протокол `APIClientProtocol` с методами для питомцев, напоминаний, веса, дневника, статей, постов, чата, профиля.
- **Endpoints** — константы путей API (базовый URL заготовлен под реальный бэкенд).
- **Mock/MockData** — статические мок-данные (pets, reminders, weightHistory, diary, articles, posts, user).
- **Mock/MockAPIClient** — реализация `APIClientProtocol`, возвращающая моки; имитация задержки и простые ответы AI для чата.

Подключение реального API: создать класс `RealAPIClient: APIClientProtocol` с URLSession/async, заменить в `AppState(api: RealAPIClient())`.

---

### 5. Домен (`Core/Domain/`)

- **Models** — `Pet`, `Vaccination`, `Reminder`, `ReminderType`, `WeightRecord`, `HealthDiaryEntry`, `Article`, `ChatMessage`, `ChatRole`, `Comment`, `Post`, `UserProfile`.

Модели используются в UI, в AppState и в API-протоколе.

---

### 6. Экраны (Features)

- **Home** — приветствие, блок «Мои питомцы», задачи на сегодня, ближайшие, быстрые действия (Советы AI, Лента). Навигация по `AppRoute`.
- **Pets** — `PetListViewModel` (список + кнопка «Добавить»), `AddPetSheet`, `PetDetailView` (карточка питомца, редактирование, удаление), `EditPetSheet`.
- **Health** — выбор питомца, табы Задачи / Вес / Дневник; напоминания с фильтром по типу, прогресс, график веса (Charts), записи дневника; шеды добавления напоминания, записи веса, записи дневника.
- **Feed** — заголовок, клубы (чипы), список постов с лайками и раскрывающимися комментариями, создание поста.
- **Profile** — аватар, имя, био, статистика, блок питомцев, табы «Мои посты» / «Понравилось», настройки, редактирование профиля.
- **Chat** — приветствие, быстрые вопросы, список сообщений, индикатор «печатает», поле ввода; ответы приходят через `app.sendChatMessage` (мок AI).

---

## Проверка себя

- **Дизайн-компоненты** — вынесены в отдельные файлы, переиспользуются на экранах, без прямой зависимости от API.
- **Навигация** — один enum `AppRoute`, табы + стек; чат доступен с таба и с главной.
- **Бизнес-логика** — сосредоточена в `AppState`; экраны только отображают и вызывают методы.
- **Сетевой слой** — протокол `APIClientProtocol`, мок-реализация и мок-данные; эндпоинты вынесены в `Endpoints`, готовность к замене на реальные запросы.

Замечания:

- Сборка в текущей среде не выполнялась (формат проекта Xcode новее установленной версии); структура кода и линтер ошибок не показывают.
- Часть экранов (например, статьи по категориям как в веб-дизайне) можно добавить позже поверх существующей навигации и данных.

---

## Вывод

Реализована SwiftUI-копия Pet Care Mobile App Design с разделением на дизайн-компоненты, отдельной бизнес-логикой в `AppState` и выделенным сетевым слоем с моками. Навигация построена на `AppRoute` и табах; данные загружаются и меняются через один слой (AppState + APIClient). Для перехода на бэкенд достаточно реализовать `APIClientProtocol` и подставить его в `AppState`.
