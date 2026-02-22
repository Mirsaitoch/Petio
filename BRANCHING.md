# Ветки и Pull Request'ы

Правила создания pull request'ов через ветки в репозитории Petio-Mono.

---

## Типы веток

| Префикс | Назначение | Пример |
|--------|------------|--------|
| `feature/` | Новая функциональность | `feature/feed-fade`, `feature/health-reminders` |
| `fix/` | Исправление бага | `fix/crash-on-empty-feed`, `fix/avatar-loading` |
| `refactor/` | Рефакторинг без изменения поведения | `refactor/split-feed-views` |
| `docs/` | Только документация | `docs/branching-rules`, `docs/api` |
| `chore/` | Сборка, тулзы, зависимости | `chore/update-deps`, `chore/xcode-15` |
| `release/` | Подготовка релиза | `release/1.2.0` |
| `hotfix/` | Срочное исправление в продакшене | `hotfix/login-crash` |

Имя ветки после префикса — короткое, через дефис, на английском:  
`feature/dark-mode`, `fix/profile-avatar`.

---

## Правила создания PR

1. **Ветка от актуальной цели**
   - Обычно от `main`.
   - Перед созданием ветки: `git fetch` и `git pull` в целевую ветку.

2. **Одна ветка — одна задача**
   - Один PR = одна фича/фикс/рефакторинг.
   - Не смешивать в одном PR несвязанные изменения.

3. **Имя ветки = суть изменений**
   - Понятно по имени, что делает ветка: `feature/feed-fade`, `fix/health-date-format`.

4. **Перед открытием PR**
   - Прогнать линтер/тесты (если есть).
   - Убедиться, что сборка проходит.
   - Подтянуть целевую ветку в свою: `git fetch origin main && git rebase origin/main` (или merge — по правилам команды).

5. **Описание PR**
   - Заголовок: кратко, что сделано (например: «Добавлен фейд сверху ленты»).
   - В описании: что изменено, зачем, как проверить (шаги).
   - Ссылка на задачу (issue), если есть.
---

## Примеры

```bash
# Новая фича
git checkout main
git pull origin main
git checkout -b feature/feed-top-fade
# правки...
git add . && git commit -m "feat(feed): add top fade for scroll content"
git push -u origin feature/feed-top-fade
# открыть PR в main

# Фикс
git checkout -b fix/profile-empty-state
# правки...
git commit -m "fix(profile): handle empty posts list"
git push -u origin fix/profile-empty-state
```

---

## Краткая шпаргалка по типам веток

- **feature/** — новая возможность для пользователя.
- **fix/** — исправление ошибки.
- **refactor/** — улучшение кода без новой функциональности.
- **docs/** — только изменения в документации.
- **chore/** — настройки, зависимости, скрипты.
- **release/** — версия для релиза.
- **hotfix/** — срочный фикс в продакшене.
