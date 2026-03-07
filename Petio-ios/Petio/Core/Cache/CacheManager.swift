import Foundation

struct CacheManager {
    private let userDefaults = UserDefaults.standard

    private enum CacheKeys {
        static let pets = "petio_cache_pets"
        static let reminders = "petio_cache_reminders"
        static let diaryEntries = "petio_cache_diary_entries"
    }

    // MARK: - Pets

    func savePets(_ pets: [Pet]) {
        if let encoded = try? JSONEncoder().encode(pets) {
            userDefaults.set(encoded, forKey: CacheKeys.pets)
            print("💾 Питомцы сохранены в кеш: \(pets.count) шт.")
        }
    }

    func loadPets() -> [Pet] {
        guard let data = userDefaults.data(forKey: CacheKeys.pets),
              let pets = try? JSONDecoder().decode([Pet].self, from: data) else {
            return []
        }
        print("📖 Питомцы загружены из кеша: \(pets.count) шт.")
        return pets
    }

    // MARK: - Reminders

    func saveReminders(_ reminders: [Reminder]) {
        if let encoded = try? JSONEncoder().encode(reminders) {
            userDefaults.set(encoded, forKey: CacheKeys.reminders)
            print("💾 Напоминания сохранены в кеш: \(reminders.count) шт.")
        }
    }

    func loadReminders() -> [Reminder] {
        guard let data = userDefaults.data(forKey: CacheKeys.reminders),
              let reminders = try? JSONDecoder().decode([Reminder].self, from: data) else {
            return []
        }
        print("📖 Напоминания загружены из кеша: \(reminders.count) шт.")
        return reminders
    }

    // MARK: - Diary Entries

    func saveDiaryEntries(_ entries: [HealthDiaryEntry]) {
        if let encoded = try? JSONEncoder().encode(entries) {
            userDefaults.set(encoded, forKey: CacheKeys.diaryEntries)
            print("💾 Записи дневника сохранены в кеш: \(entries.count) шт.")
        }
    }

    func loadDiaryEntries() -> [HealthDiaryEntry] {
        guard let data = userDefaults.data(forKey: CacheKeys.diaryEntries),
              let entries = try? JSONDecoder().decode([HealthDiaryEntry].self, from: data) else {
            return []
        }
        print("📖 Записи дневника загружены из кеша: \(entries.count) шт.")
        return entries
    }

    // MARK: - Clear

    func clearAll() {
        userDefaults.removeObject(forKey: CacheKeys.pets)
        userDefaults.removeObject(forKey: CacheKeys.reminders)
        userDefaults.removeObject(forKey: CacheKeys.diaryEntries)
        print("🗑️ Кеш очищен")
    }
}
