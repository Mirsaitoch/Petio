//
//  HTTPAPIClient.swift
//  Petio
//
//  Real HTTP implementation of APIClientProtocol using URLSession.
//  Attaches JWT token to every request. Auto-logout on 401.
//

import Foundation

final class HTTPAPIClient: APIClientProtocol, @unchecked Sendable {

    private let baseURL: String
    private let authManager: AuthManager

    init(authManager: AuthManager, baseURL: String = "http://localhost:8080/v1") {
        self.authManager = authManager
        self.baseURL = baseURL
    }

    // MARK: - Request Builders

    private func makeRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authManager.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        if http.statusCode == 401 {
            authManager.deleteToken()
            throw APIError.server(401)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func performVoid(_ request: URLRequest) async throws {
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        if http.statusCode == 401 {
            authManager.deleteToken()
            throw APIError.server(401)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(http.statusCode)
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do { return try JSONEncoder().encode(value) }
        catch { throw APIError.decoding(error) }
    }

    // MARK: - Pets

    func fetchPets() async throws -> [Pet] {
        try await perform(try makeRequest(path: "/pets"))
    }

    func fetchPet(id: String) async throws -> Pet? {
        try await perform(try makeRequest(path: "/pets/\(id)"))
    }

    func addPet(_ pet: Pet) async throws -> Pet {
        try await perform(try makeRequest(path: "/pets", method: "POST", body: encode(pet)))
    }

    func updatePet(_ pet: Pet) async throws -> Pet {
        try await perform(try makeRequest(path: "/pets/\(pet.id)", method: "PUT", body: encode(pet)))
    }

    func deletePet(id: String) async throws {
        try await performVoid(try makeRequest(path: "/pets/\(id)", method: "DELETE"))
    }

    // MARK: - Reminders

    func fetchReminders(petId: String?) async throws -> [Reminder] {
        var qi: [URLQueryItem] = []
        if let id = petId { qi = [URLQueryItem(name: "petId", value: id)] }
        return try await perform(try makeRequest(path: "/reminders", queryItems: qi))
    }

    func addReminder(_ reminder: Reminder) async throws -> Reminder {
        try await perform(try makeRequest(path: "/reminders", method: "POST", body: encode(reminder)))
    }

    func updateReminder(_ reminder: Reminder) async throws -> Reminder {
        try await perform(try makeRequest(path: "/reminders/\(reminder.id)", method: "PUT", body: encode(reminder)))
    }

    func deleteReminder(id: String) async throws {
        try await performVoid(try makeRequest(path: "/reminders/\(id)", method: "DELETE"))
    }

    // MARK: - Weight

    func fetchWeightHistory(petId: String) async throws -> [WeightRecord] {
        try await perform(try makeRequest(path: "/pets/\(petId)/weight"))
    }

    func addWeightRecord(petId: String, _ record: WeightRecord) async throws {
        try await performVoid(try makeRequest(path: "/pets/\(petId)/weight", method: "POST", body: encode(record)))
    }

    // MARK: - Diary

    func fetchDiary(petId: String) async throws -> [HealthDiaryEntry] {
        try await perform(try makeRequest(path: "/pets/\(petId)/diary"))
    }

    func addDiaryEntry(_ entry: HealthDiaryEntry) async throws -> HealthDiaryEntry {
        try await perform(try makeRequest(path: "/pets/\(entry.petId)/diary", method: "POST", body: encode(entry)))
    }

    func updateDiaryEntry(_ entry: HealthDiaryEntry) async throws {
        try await performVoid(try makeRequest(path: "/diary/\(entry.id)", method: "PUT", body: encode(entry)))
    }

    func deleteDiaryEntry(id: String) async throws {
        try await performVoid(try makeRequest(path: "/diary/\(id)", method: "DELETE"))
    }

    // MARK: - Articles

    func fetchArticles() async throws -> [Article] {
        try await perform(try makeRequest(path: "/articles"))
    }

    // MARK: - Posts

    func fetchPosts(club: String?) async throws -> [Post] {
        var qi: [URLQueryItem] = []
        if let club = club, club != "Все" { qi = [URLQueryItem(name: "club", value: club)] }
        return try await perform(try makeRequest(path: "/posts", queryItems: qi))
    }

    func addPost(_ post: Post) async throws -> Post {
        try await perform(try makeRequest(path: "/posts", method: "POST", body: encode(post)))
    }

    func addPostWithImage(_ post: Post, imageData: Data) async throws -> Post {
        // Step 1: upload image, get URL from /upload/post-image
        let imageURL = try await uploadPostImage(imageData: imageData)
        // Step 2: create post via JSON with image URL
        var postWithImage = post
        postWithImage.image = imageURL
        return try await perform(try makeRequest(path: "/posts", method: "POST", body: encode(postWithImage)))
    }

    private func uploadPostImage(imageData: Data) async throws -> String {
        let boundary = UUID().uuidString
        guard let url = URLComponents(string: baseURL + "/upload/post-image")?.url else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authManager.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = buildFileUploadBody(imageData: imageData, boundary: boundary)
        struct UploadResponse: Decodable { let url: String }
        let response: UploadResponse = try await perform(req)
        return response.url
    }

    private func buildFileUploadBody(imageData: Data, boundary: String) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        append("\r\n")
        append("--\(boundary)--\r\n")
        return body
    }

    func likePost(id: String, liked: Bool) async throws {
        struct LikeBody: Encodable { let liked: Bool }
        try await performVoid(try makeRequest(
            path: "/posts/\(id)/like", method: "POST", body: encode(LikeBody(liked: liked))
        ))
    }

    func addComment(postId: String, _ comment: Comment) async throws {
        try await performVoid(try makeRequest(
            path: "/posts/\(postId)/comments", method: "POST", body: encode(comment)
        ))
    }

    // MARK: - Chat

    func sendChatMessage(_ text: String) async throws -> String {
        struct SendBody: Encodable { let text: String }
        struct ChatResponse: Decodable { let reply: String }
        let resp: ChatResponse = try await perform(try makeRequest(
            path: "/chat/send", method: "POST", body: encode(SendBody(text: text))
        ))
        return resp.reply
    }

    // MARK: - Profile

    func fetchProfile() async throws -> UserProfile {
        try await perform(try makeRequest(path: "/profile"))
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        try await perform(try makeRequest(path: "/profile", method: "PUT", body: encode(profile)))
    }
}
