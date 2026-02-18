//
//  APIClient.swift
//  Petio
//
//  Сетевой слой: протокол клиента API. Реализация — реальный HTTP или Mock.
//

import Foundation

enum APIError: Error {
    case invalidURL
    case network(Error)
    case decoding(Error)
    case server(Int)
}

/// Протокол API-клиента. Реальные ручки подключаются здесь; пока используется MockAPIClient.
protocol APIClientProtocol: Sendable {
    func fetchPets() async throws -> [Pet]
    func fetchPet(id: String) async throws -> Pet?
    func addPet(_ pet: Pet) async throws -> Pet
    func updatePet(_ pet: Pet) async throws -> Pet
    func deletePet(id: String) async throws

    func fetchReminders(petId: String?) async throws -> [Reminder]
    func addReminder(_ reminder: Reminder) async throws -> Reminder
    func updateReminder(_ reminder: Reminder) async throws -> Reminder
    func deleteReminder(id: String) async throws

    func fetchWeightHistory(petId: String) async throws -> [WeightRecord]
    func addWeightRecord(petId: String, _ record: WeightRecord) async throws

    func fetchDiary(petId: String) async throws -> [HealthDiaryEntry]
    func addDiaryEntry(_ entry: HealthDiaryEntry) async throws -> HealthDiaryEntry
    func updateDiaryEntry(_ entry: HealthDiaryEntry) async throws
    func deleteDiaryEntry(id: String) async throws

    func fetchArticles() async throws -> [Article]

    func fetchPosts(club: String?) async throws -> [Post]
    func addPost(_ post: Post) async throws -> Post
    func likePost(id: String, liked: Bool) async throws
    func addComment(postId: String, _ comment: Comment) async throws

    func sendChatMessage(_ text: String) async throws -> String

    func fetchProfile() async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
}
