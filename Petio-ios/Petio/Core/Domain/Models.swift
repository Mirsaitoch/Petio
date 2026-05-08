//
//  Models.swift
//  Petio
//
//  Доменные модели приложения Pet Care.
//  Приоритет: структура бэкенда (Go). iOS модели синхронизированы с backend/internal/domain/.
//

import Foundation

// MARK: - Date Helpers

/// Парсит дату из строки — поддерживает как ISO8601/RFC3339, так и "yyyy-MM-dd".
enum DateHelper {
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Парсит строку в Date. Поддерживает RFC3339 и "yyyy-MM-dd".
    static func parse(_ string: String) -> Date? {
        if let d = iso8601Formatter.date(from: string) { return d }
        if let d = iso8601NoFrac.date(from: string) { return d }
        if let d = dateOnlyFormatter.date(from: string) { return d }
        return nil
    }

    /// Форматирует Date в "yyyy-MM-dd" строку.
    static func dateString(from date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    /// Извлекает "yyyy-MM-dd" из любой строки даты (RFC3339 или уже yyyy-MM-dd).
    static func normalizeToDateOnly(_ string: String) -> String {
        if let date = parse(string) {
            return dateString(from: date)
        }
        return string
    }
}

// MARK: - Pet

struct Pet: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var species: String
    var breed: String
    var age: Int
    var weight: Double
    var photo: String?
    var birthDate: String
    var vaccinations: [Vaccination]
    var features: [String]

    /// Вычисляемый возраст для отображения (на основе birthDate).
    var ageDisplay: String {
        PetAgeCalculator.computedAge(from: DateHelper.normalizeToDateOnly(birthDate))
    }
}

struct Vaccination: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var date: String
    var nextDate: String?
}

// MARK: - Reminder

struct Reminder: Identifiable, Equatable, Codable {
    let id: String
    let petId: String
    var petName: String
    var type: ReminderType
    var title: String
    var date: String
    var time: String
    var completed: Bool
}

enum ReminderType: String, Codable, CaseIterable {
    case feeding
    case vaccination
    case deworming
    case grooming

    var label: String {
        switch self {
        case .feeding: return "Кормление"
        case .vaccination: return "Прививка"
        case .deworming: return "Обработка"
        case .grooming: return "Груминг"
        }
    }
}

// MARK: - Health

struct WeightRecord: Equatable, Codable {
    var date: String
    var weight: Double
}

struct DiaryTag: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var colorHex: String   // e.g. "#4CAF50"
    var isDefault: Bool
}

/// HealthDiaryEntry — tags хранятся только локально, бэкенд их не поддерживает.
struct HealthDiaryEntry: Identifiable, Equatable, Codable {
    let id: String
    let petId: String
    var date: String
    var note: String
    /// Локальные теги (не отправляются/получаются с бэкенда).
    var tags: [DiaryTag]

    enum CodingKeys: String, CodingKey {
        case id, petId, date, note
    }

    init(id: String, petId: String, date: String, note: String, tags: [DiaryTag] = []) {
        self.id = id
        self.petId = petId
        self.date = date
        self.note = note
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        petId = try c.decode(String.self, forKey: .petId)
        date = try c.decode(String.self, forKey: .date)
        note = try c.decode(String.self, forKey: .note)
        tags = []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(petId, forKey: .petId)
        try c.encode(date, forKey: .date)
        try c.encode(note, forKey: .note)
    }
}

// MARK: - Article

struct Article: Identifiable, Equatable, Codable {
    let id: String
    var title: String
    var description: String
    var category: String
    var image: String?
    var petType: String
    var careType: String
    var readTime: Int
}

// MARK: - Chat

struct Chat: Identifiable, Equatable, Codable {
    let id: String
    var title: String
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: String
    var chatId: String
    var role: String  // "user", "assistant", "system"
    var content: String
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case role, content
        case createdAt = "created_at"
    }

    /// Удобный инициализатор для создания локальных сообщений.
    init(id: String, chatId: String, role: String, content: String, createdAt: String = "") {
        self.id = id
        self.chatId = chatId
        self.role = role
        self.content = content
        self.createdAt = createdAt.isEmpty ? ISO8601DateFormatter().string(from: Date()) : createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        chatId = try c.decodeIfPresent(String.self, forKey: .chatId) ?? ""
        role = try c.decode(String.self, forKey: .role)
        content = try c.decode(String.self, forKey: .content)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
}

// MARK: - Feed

struct Comment: Identifiable, Equatable, Codable {
    let id: String
    var author: String
    var avatar: String?
    var content: String
    var timestamp: String
}

struct Post: Identifiable, Equatable, Codable {
    let id: String
    var author: String
    var avatar: String?
    var content: String
    var image: String?
    var likes: Int
    var comments: [Comment]
    var club: String
    var timestamp: String
    var liked: Bool
}

// MARK: - Feed Pagination

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

// MARK: - User

struct UserProfile: Equatable, Codable {
    var name: String
    var username: String
    var avatar: String?
    var bio: String
    var petsCount: Int
    var postsCount: Int
    var joinDate: String

    var email: String?

    enum CodingKeys: String, CodingKey {
        case name, username, avatar, bio, petsCount, postsCount, joinDate, email
    }
}
