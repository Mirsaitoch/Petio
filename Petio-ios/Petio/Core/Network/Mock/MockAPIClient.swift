//
//  MockAPIClient.swift
//  Petio
//
//  Реализация APIClient с мок-данными. Подмена на реальный HTTP-клиент — в DI/Environment.
//

import Foundation

final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    func fetchPets() async throws -> [Pet] { MockData.pets }
    func fetchPet(id: String) async throws -> Pet? { MockData.pets.first { $0.id == id } }
    func addPet(_ pet: Pet) async throws -> Pet { pet }
    func updatePet(_ pet: Pet) async throws -> Pet { pet }
    func deletePet(id: String) async throws { }

    func fetchReminders(petId: String?) async throws -> [Reminder] {
        let list = MockData.reminders
        guard let petId = petId else { return list }
        return list.filter { $0.petId == petId }
    }
    func addReminder(_ reminder: Reminder) async throws -> Reminder { reminder }
    func updateReminder(_ reminder: Reminder) async throws -> Reminder { reminder }
    func deleteReminder(id: String) async throws { }

    func fetchWeightHistory(petId: String) async throws -> [WeightRecord] {
        MockData.weightHistory[petId] ?? []
    }
    func addWeightRecord(petId: String, _ record: WeightRecord) async throws { }

    func fetchDiary(petId: String) async throws -> [HealthDiaryEntry] {
        MockData.diary.filter { $0.petId == petId }
    }
    func addDiaryEntry(_ entry: HealthDiaryEntry) async throws -> HealthDiaryEntry { entry }
    func updateDiaryEntry(_ entry: HealthDiaryEntry) async throws { }
    func deleteDiaryEntry(id: String) async throws { }

    func fetchArticles() async throws -> [Article] { MockData.articles }

    func fetchPosts(club: String?) async throws -> [Post] {
        let list = MockData.posts
        guard let club = club, club != "Все" else { return list }
        return list.filter { $0.club == club }
    }
    func addPost(_ post: Post) async throws -> Post { post }
    func likePost(id: String, liked: Bool) async throws { }
    func addComment(postId: String, _ comment: Comment) async throws { }

    func sendChatMessage(_ text: String) async throws -> String {
        try await Task.sleep(nanoseconds: 800_000_000)
        return MockAIService.response(for: text)
    }

    func fetchProfile() async throws -> UserProfile { MockData.user }
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile { profile }
}

// Простой мок ответов AI для чата
private enum MockAIService {
    static func response(for message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("корм") || lower.contains("питани") {
            return "Питание — важнейший аспект здоровья вашего питомца! 🍽\n\nОсновные правила:\n• Выбирайте качественный корм по возрасту и виду\n• Соблюдайте режим кормления\n• Всегда доступ к чистой воде"
        }
        if lower.contains("прививк") || lower.contains("вакцин") {
            return "Схема вакцинации:\n\n🐕 Собаки: 8–9 нед — первая прививка, 12 нед — ревакцинация + бешенство, далее ежегодно.\n🐱 Кошки: аналогично. Обработка от глистов за 10–14 дней до прививки! 💉"
        }
        if lower.contains("лоток") || lower.contains("туалет") {
            return "Приучение к лотку:\n1️⃣ Лоток в тихое место\n2️⃣ После еды и сна — в лоток\n3️⃣ Хвалите за успех, не ругайте за промахи\n4️⃣ Держите лоток чистым. Обычно 1–2 недели! 🐱"
        }
        return "Отличный вопрос! 🐾 Могу посоветовать по кормлению, вакцинации, грумингу и поведению. Задайте конкретный вопрос!"
    }
}
