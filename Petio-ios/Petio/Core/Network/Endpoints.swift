//
//  Endpoints.swift
//  Petio
//
//  Пути API эндпоинтов. Синхронизированы с backend/internal/transport/http/router.go.
//

import Foundation

enum Endpoints {
    static var baseURL: URL? { URL(string: "http://158.160.235.224/v1") }

    // Питомцы
    static func pets() -> String { "/pets" }
    static func pet(id: String) -> String { "/pets/\(id)" }

    // Напоминания
    static func reminders() -> String { "/reminders" }
    static func reminder(id: String) -> String { "/reminders/\(id)" }

    // Вес
    static func weightRecords(petId: String) -> String { "/pets/\(petId)/weight" }

    // Дневник здоровья
    static func diaryEntries(petId: String) -> String { "/pets/\(petId)/diary" }
    static func diaryEntry(id: String) -> String { "/diary/\(id)" }

    // Статьи
    static func articles() -> String { "/articles" }
    static func article(id: String) -> String { "/articles/\(id)" }

    // Лента
    static func posts() -> String { "/posts" }
    static func post(id: String) -> String { "/posts/\(id)" }
    static func likePost(id: String) -> String { "/posts/\(id)/like" }
    static func comments(postId: String) -> String { "/posts/\(postId)/comments" }

    // Чат / AI (мульти-чат)
    static func chats() -> String { "/chats" }
    static func chat(id: String) -> String { "/chats/\(id)" }
    static func chatMessages(chatId: String) -> String { "/chats/\(chatId)/messages" }
    static func chatStats() -> String { "/chats/stats" }

    // Загрузка файлов
    static func uploadPostImage() -> String { "/upload/post-image" }
    static func uploadPetPhoto() -> String { "/upload/pet-photo" }
    static func uploadAvatar() -> String { "/upload/avatar" }

    // Пользователь
    static func profile() -> String { "/profile" }
}
