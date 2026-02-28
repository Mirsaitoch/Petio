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
    var features: [String]
}

struct Vaccination: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var date: String
    var nextDate: String
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

struct HealthDiaryEntry: Identifiable, Equatable, Codable {
    let id: String
    let petId: String
    var date: String
    var note: String
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
    var name: String
    var username: String
    var avatar: String?
    var bio: String
    var petsCount: Int
    var postsCount: Int
    var joinDate: String
}
