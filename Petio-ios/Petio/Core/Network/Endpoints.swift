//
//  Endpoints.swift
//  Petio
//
//  Описание API-эндпоинтов. Подключение реального бэкенда — подставить базовый URL и вызывать через APIClient.
//

import Foundation

enum Endpoints {
    static var baseURL: URL? { URL(string: "http://localhost:8080/v1") }

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

    // Статьи
    static func articles() -> String { "/articles" }
    static func article(id: String) -> String { "/articles/\(id)" }

    // Лента
    static func posts() -> String { "/posts" }
    static func post(id: String) -> String { "/posts/\(id)" }
    static func likePost(id: String) -> String { "/posts/\(id)/like" }
    static func comments(postId: String) -> String { "/posts/\(postId)/comments" }

    // Чат / AI
    static func chatSend() -> String { "/chat/send" }

    // Пользователь
    static func profile() -> String { "/profile" }
}
