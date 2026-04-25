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
    private let cacheManager = CacheManager()

    init(authManager: AuthManager, baseURL: String = "http://158.160.235.224/v1") {
        self.authManager = authManager
        self.baseURL = baseURL
    }

    // MARK: - Request Builders

    private func makeRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        includeAuth: Bool = true
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
        if includeAuth, let token = authManager.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        logRequest(request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        logResponse(http, data)
        if http.statusCode == 401 {
            // Attempt to refresh token
            if let _ = try? await refreshAccessToken() {
                // Refresh succeeded, retry the request with new token
                var retryRequest = request
                if let newToken = authManager.getToken() {
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else {
                    throw APIError.network(URLError(.badServerResponse))
                }
                guard (200..<300).contains(retryHttp.statusCode) else {
                    throw APIError.server(retryHttp.statusCode)
                }
                do {
                    return try JSONDecoder().decode(T.self, from: retryData)
                } catch {
                    throw APIError.decoding(error)
                }
            } else {
                // Refresh failed, delete token and throw
                authManager.deleteToken()
                throw APIError.server(401)
            }
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
            // Attempt to refresh token
            if let _ = try? await refreshAccessToken() {
                // Refresh succeeded, retry the request with new token
                var retryRequest = request
                if let newToken = authManager.getToken() {
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                let (_, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else {
                    throw APIError.network(URLError(.badServerResponse))
                }
                guard (200..<300).contains(retryHttp.statusCode) else {
                    throw APIError.server(retryHttp.statusCode)
                }
                return
            } else {
                // Refresh failed, delete token and throw
                authManager.deleteToken()
                throw APIError.server(401)
            }
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(http.statusCode)
        }
    }

    private func refreshAccessToken() async throws -> String {
        print("[API] refreshAccessToken: starting")
        guard let refreshToken = authManager.getRefreshToken() else {
            print("[API] refreshAccessToken: no refreshToken found")
            throw APIError.server(401)
        }

        struct RefreshRequest: Encodable {
            let refreshToken: String
        }

        struct RefreshResponse: Decodable {
            let token: String
            let refreshToken: String
        }

        // Don't include expired token when refreshing
        let request = try makeRequest(
            path: "/auth/refresh",
            method: "POST",
            body: encode(RefreshRequest(refreshToken: refreshToken)),
            includeAuth: false
        )

        print("[API] refreshAccessToken: sending request")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            print("[API] refreshAccessToken: bad response")
            throw APIError.network(URLError(.badServerResponse))
        }

        print("[API] refreshAccessToken: got status \(http.statusCode)")
        guard (200..<300).contains(http.statusCode) else {
            print("[API] refreshAccessToken: refresh failed with status \(http.statusCode)")
            throw APIError.server(http.statusCode)
        }

        do {
            let refreshResponse = try JSONDecoder().decode(RefreshResponse.self, from: data)
            authManager.saveToken(refreshResponse.token)
            authManager.saveRefreshToken(refreshResponse.refreshToken)
            print("[API] refreshAccessToken: success, new token saved")
            return refreshResponse.token
        } catch {
            print("[API] refreshAccessToken: decoding failed - \(error)")
            throw APIError.decoding(error)
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do { return try JSONEncoder().encode(value) }
        catch { throw APIError.decoding(error) }
    }

    private func isNetworkError(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else {
            if let urlError = error as? URLError {
                return isNetworkURLError(urlError)
            }
            return false
        }

        if case .network(let innerError) = apiError {
            if let urlError = innerError as? URLError {
                return isNetworkURLError(urlError)
            }
        }
        return false
    }

    private func isNetworkURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet, .timedOut, .badServerResponse, .networkConnectionLost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    // MARK: - Pets

    func fetchPets() async throws -> [Pet] {
        do {
            let pets: [Pet] = try await perform(try makeRequest(path: "/pets"))
            cacheManager.savePets(pets)
            return pets
        } catch let error {
            if isNetworkError(error) {
                print("⚠️ Сеть недоступна, загружаю питомцев из кеша")
                return cacheManager.loadPets()
            }
            throw error
        }
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
        do {
            var qi: [URLQueryItem] = []
            if let id = petId { qi = [URLQueryItem(name: "petId", value: id)] }
            let reminders: [Reminder] = try await perform(try makeRequest(path: "/reminders", queryItems: qi))
            cacheManager.saveReminders(reminders)
            return reminders
        } catch let error {
            if isNetworkError(error) {
                print("⚠️ Сеть недоступна, загружаю напоминания из кеша")
                return cacheManager.loadReminders()
            }
            throw error
        }
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
        do {
            let entries: [HealthDiaryEntry] = try await perform(try makeRequest(path: "/pets/\(petId)/diary"))
            cacheManager.saveDiaryEntries(entries)
            return entries
        } catch let error {
            if isNetworkError(error) {
                print("⚠️ Сеть недоступна, загружаю дневник из кеша")
                return cacheManager.loadDiaryEntries()
            }
            throw error
        }
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

    func fetchPosts(
        club: String?,
        limit: Int = 20,
        afterID: String? = nil,
        beforeID: String? = nil
    ) async throws -> PostsResponse {
        var qi: [URLQueryItem] = []
        if limit != 0 { qi.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let afterID = afterID { qi.append(URLQueryItem(name: "after_id", value: afterID)) }
        if let beforeID = beforeID { qi.append(URLQueryItem(name: "before_id", value: beforeID)) }
        if let club = club, club != "Все" { qi.append(URLQueryItem(name: "club", value: club)) }

        print("[POSTS] fetchPosts запрос: club='\(club ?? "nil")', limit=\(limit), afterID=\(afterID ?? "nil"), beforeID=\(beforeID ?? "nil")")

        do {
            let response: PostsResponse = try await perform(try makeRequest(path: "/posts", queryItems: qi))
            print("[POSTS] fetchPosts успех: получено \(response.posts.count) постов, hasMore=\(response.hasMore), hasNew=\(response.hasNew)")
            return response
        } catch {
            print("[POSTS] fetchPosts ошибка: \(error)")
            throw error
        }
    }

    func addPost(_ post: Post) async throws -> Post {
        print("[POSTS] addPost запрос: author='\(post.author)', content='\(post.content.prefix(50))', club='\(post.club)', image=\(post.image ?? "nil")")
        do {
            let result: Post = try await perform(try makeRequest(path: "/posts", method: "POST", body: encode(post)))
            print("[POSTS] addPost успех: id=\(result.id), image=\(result.image ?? "nil")")
            return result
        } catch {
            print("[POSTS] addPost ошибка: \(error)")
            throw error
        }
    }

    func addPostWithImage(_ post: Post, imageData: Data) async throws -> Post {
        print("[POSTS] addPostWithImage запрос: author='\(post.author)', content='\(post.content.prefix(50))', imageSize=\(imageData.count) bytes")
        // Step 1: upload image, get URL from /upload/post-image
        let imageURL = try await uploadPostImage(imageData: imageData)
        print("[POSTS] addPostWithImage: imageURL='\(imageURL)'")
        // Step 2: create post via JSON with image URL
        var postWithImage = post
        postWithImage.image = imageURL
        let result: Post = try await perform(try makeRequest(path: "/posts", method: "POST", body: encode(postWithImage)))
        print("[POSTS] addPostWithImage успех: id=\(result.id), image=\(result.image ?? "nil")")
        return result
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
        print("[DEBUG] uploadPostImage → url = \(response.url)")
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

    private func logRequest(_ request: URLRequest) {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        let hasAuth = request.value(forHTTPHeaderField: "Authorization") != nil
        print("[API] \(method) \(url) \(hasAuth ? "(auth)" : "(no auth)")")
        if let body = request.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
            print("[API] Body: \(bodyStr)")
        }
    }

    private func logResponse(_ response: HTTPURLResponse, _ data: Data) {
        let status = response.statusCode
        let url = response.url?.absoluteString ?? "unknown"
        print("[API] Response \(status) from \(url)")
        if let responseStr = String(data: data, encoding: .utf8) {
            print("[API] Data: \(responseStr.prefix(200))")
        }
    }
}

extension HTTPAPIClient {
    static let shared = HTTPAPIClient(authManager: AuthManager.shared)
}
