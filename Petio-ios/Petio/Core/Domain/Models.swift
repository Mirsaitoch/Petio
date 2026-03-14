//
//  Models.swift
//  Petio
//
//  Доменные модели приложения Pet Care.
//

import Foundation

// MARK: - Pet

struct Pet: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var species: String
    var breed: String
    var age: String
    var weight: Double
    var photo: String?
    var birthDate: String
    var vaccinations: [Vaccination]
    var treatments: [Treatment]
    var features: [String]
}

struct Vaccination: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var date: String
    var nextDate: String
}

struct Treatment: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var date: String
}

// MARK: - Reminder

struct Reminder: Identifiable, Equatable, Codable {
    let id: String
    let petId: String
    var petName: String
    var type: ReminderType
    var customTypeName: String?
    var title: String
    var date: String
    var time: String
    var completed: Bool

    var typeDisplayName: String {
        if type == .other, let name = customTypeName, !name.isEmpty { return name }
        return type.label
    }
}

enum ReminderType: String, Codable, CaseIterable {
    case feeding
    case vaccination
    case deworming
    case grooming
    case other

    var label: String {
        switch self {
        case .feeding: return "Кормление"
        case .vaccination: return "Прививка"
        case .deworming: return "Обработка"
        case .grooming: return "Груминг"
        case .other: return "Другой"
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

struct HealthDiaryEntry: Identifiable, Equatable, Codable {
    let id: String
    let petId: String
    var date: String
    var note: String
    var tags: [DiaryTag]
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
    var readTime: String
}

// MARK: - Chat

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: String
    var role: ChatRole
    var content: String
    var timestamp: Date
}

enum ChatRole: String, Codable {
    case user
    case assistant
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

// MARK: - User

struct UserProfile: Equatable, Codable {
    var username: String
    var email: String?
    var avatar: String?
    var bio: String
    var petsCount: Int
    var postsCount: Int
    var joinDate: String
}
