//
//  APIClient.swift
//  Petio
//
//  Протокол API-клиента. Синхронизирован с бэкендом (backend/internal/transport/http/router.go).
//

import Foundation

enum APIError: Error {
    case invalidURL
    case network(Error)
    case decoding(Error)
    case server(Int)
}

protocol APIClientProtocol: Sendable {
    // MARK: - Pets
    func fetchPets() async throws -> [Pet]
    func fetchPet(id: String) async throws -> Pet?
    func addPet(_ pet: Pet) async throws -> Pet
    func updatePet(_ pet: Pet) async throws -> Pet
    func deletePet(id: String) async throws

    // MARK: - Reminders
    func fetchReminders(petId: String?) async throws -> [Reminder]
    func addReminder(_ reminder: Reminder) async throws -> Reminder
    func updateReminder(_ reminder: Reminder) async throws -> Reminder
    func deleteReminder(id: String) async throws

    // MARK: - Weight
    func fetchWeightHistory(petId: String) async throws -> [WeightRecord]
    func addWeightRecord(petId: String, _ record: WeightRecord) async throws

    // MARK: - Diary
    func fetchDiary(petId: String) async throws -> [HealthDiaryEntry]
    func addDiaryEntry(_ entry: HealthDiaryEntry) async throws -> HealthDiaryEntry
    func updateDiaryEntry(_ entry: HealthDiaryEntry) async throws
    func deleteDiaryEntry(id: String) async throws

    // MARK: - Articles
    func fetchArticles() async throws -> [Article]

    // MARK: - Posts
    func fetchPosts(
        club: String?,
        limit: Int,
        afterID: String?,
        beforeID: String?
    ) async throws -> PostsResponse
    func addPost(_ post: Post) async throws -> Post
    func addPostWithImage(_ post: Post, imageData: Data) async throws -> Post
    func likePost(id: String, liked: Bool) async throws
    func addComment(postId: String, _ comment: Comment) async throws

    // MARK: - Chat (мульти-чат, /v1/chats/*)
    func createChat(title: String) async throws -> Chat
    func listChats(limit: Int, offset: Int) async throws -> [Chat]
    func getChat(id: String) async throws -> Chat
    func deleteChat(id: String) async throws
    func getChatMessages(chatId: String, limit: Int, offset: Int) async throws -> [ChatMessage]
    func sendChatMessage(chatId: String, text: String) async throws -> ChatMessage

    // MARK: - Profile
    func fetchProfile() async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
}
