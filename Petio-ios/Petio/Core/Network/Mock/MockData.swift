//
//  MockData.swift
//  Petio
//
//  Мок-данные для разработки без бэкенда.
//

import Foundation

enum MockData {
    static let dogPhoto = "https://images.unsplash.com/photo-1734966213753-1b361564bab4?w=400"
    static let catPhoto = "https://images.unsplash.com/photo-1758431151210-0ba258fb2ba1?w=400"
    static let parrotPhoto = "https://images.unsplash.com/photo-1583378733378-3fee25067954?w=400"
    static let womanAvatar = "https://images.unsplash.com/photo-1760551937527-2bc6cfe45180?w=200"
    static let manAvatar = "https://images.unsplash.com/photo-1762708590808-c453c0e4fb0f?w=200"
    static let userAvatar = "https://images.unsplash.com/photo-1759744718098-8f1d1cf76ad6?w=200"
    static let groomingImg = "https://images.unsplash.com/photo-1735597403677-2029485b4547?w=400"
    static let catFoodImg = "https://images.unsplash.com/photo-1762006496712-30db6d0b5c30?w=400"
    static let vetImg = "https://images.unsplash.com/photo-1761203429504-56ece2d6eeb6?w=400"
    static let rabbitImg = "https://images.unsplash.com/photo-1643212263657-505473e76c7f?w=400"

    static var pets: [Pet] {
        [
            Pet(
                id: "1",
                name: "Барон",
                species: "Собака",
                breed: "Золотистый ретривер",
                age: "3 года",
                weight: 32,
                photo: dogPhoto,
                birthDate: "2023-03-15",
                vaccinations: [
                    Vaccination(id: "v1", name: "Бешенство", date: "2025-06-10", nextDate: "2026-06-10"),
                    Vaccination(id: "v2", name: "DHPP", date: "2025-05-01", nextDate: "2026-05-01")
                ],
                features: ["Аллергия на курицу", "Любит плавать", "Дружелюбный"]
            ),
            Pet(
                id: "2",
                name: "Мурка",
                species: "Кошка",
                breed: "Британская короткошёрстная",
                age: "2 года",
                weight: 4.5,
                photo: catPhoto,
                birthDate: "2024-01-20",
                vaccinations: [
                    Vaccination(id: "v3", name: "Бешенство", date: "2025-08-15", nextDate: "2026-08-15")
                ],
                features: ["Домашняя", "Любит тунец", "Ласковая"]
            ),
            Pet(
                id: "3",
                name: "Кеша",
                species: "Птица",
                breed: "Волнистый попугай",
                age: "1 год",
                weight: 0.04,
                photo: parrotPhoto,
                birthDate: "2025-02-10",
                vaccinations: [],
                features: ["Говорящий", "Любит яблоки", "Активный"]
            )
        ]
    }

    static var reminders: [Reminder] {
        [
            Reminder(id: "r1", petId: "1", petName: "Барон", type: .feeding, title: "Утреннее кормление", date: "2026-02-17", time: "08:00", completed: false),
            Reminder(id: "r2", petId: "1", petName: "Барон", type: .grooming, title: "Стрижка когтей", date: "2026-02-19", time: "14:00", completed: false),
            Reminder(id: "r3", petId: "2", petName: "Мурка", type: .vaccination, title: "Прививка от бешенства", date: "2026-02-20", time: "10:00", completed: false),
            Reminder(id: "r4", petId: "2", petName: "Мурка", type: .feeding, title: "Вечернее кормление", date: "2026-02-17", time: "19:00", completed: false),
            Reminder(id: "r5", petId: "1", petName: "Барон", type: .deworming, title: "Обработка от глистов", date: "2026-02-25", time: "09:00", completed: false),
            Reminder(id: "r6", petId: "3", petName: "Кеша", type: .feeding, title: "Смена воды и корма", date: "2026-02-17", time: "07:30", completed: true)
        ]
    }

    static var weightHistory: [String: [WeightRecord]] {
        [
            "1": [
                WeightRecord(date: "Сен", weight: 29),
                WeightRecord(date: "Окт", weight: 30),
                WeightRecord(date: "Ноя", weight: 30.5),
                WeightRecord(date: "Дек", weight: 31),
                WeightRecord(date: "Янв", weight: 31.5),
                WeightRecord(date: "Фев", weight: 32)
            ],
            "2": [
                WeightRecord(date: "Сен", weight: 3.8),
                WeightRecord(date: "Окт", weight: 4.0),
                WeightRecord(date: "Ноя", weight: 4.1),
                WeightRecord(date: "Дек", weight: 4.3),
                WeightRecord(date: "Янв", weight: 4.4),
                WeightRecord(date: "Фев", weight: 4.5)
            ]
        ]
    }

    static var diary: [HealthDiaryEntry] {
        [
            HealthDiaryEntry(id: "d1", petId: "1", date: "2026-02-15", note: "Барон был активен на прогулке, аппетит хороший. Заметил небольшую сухость на носу."),
            HealthDiaryEntry(id: "d2", petId: "1", date: "2026-02-10", note: "Посетили ветеринара — всё в норме. Вес стабильный."),
            HealthDiaryEntry(id: "d3", petId: "2", date: "2026-02-14", note: "Мурка стала меньше есть. Нужно понаблюдать."),
            HealthDiaryEntry(id: "d4", petId: "2", date: "2026-02-12", note: "Играла весь день, настроение отличное!")
        ]
    }

    static var articles: [Article] {
        [
            Article(id: "a1", title: "Правильное питание для собак", description: "Узнайте, как составить сбалансированный рацион для вашего питомца.", category: "Кормление", image: catFoodImg, petType: "Собака", careType: "Питание", readTime: "5 мин"),
            Article(id: "a2", title: "Вакцинация кошек: полный гид", description: "Какие прививки нужны вашей кошке и когда их делать.", category: "Здоровье", image: vetImg, petType: "Кошка", careType: "Вакцинация", readTime: "7 мин"),
            Article(id: "a3", title: "Груминг собак в домашних условиях", description: "Пошаговое руководство по уходу за шерстью, когтями и зубами.", category: "Груминг", image: groomingImg, petType: "Собака", careType: "Груминг", readTime: "6 мин"),
            Article(id: "a4", title: "Уход за попугаем: шпаргалка", description: "Всё, что нужно знать о содержании попугаев.", category: "Общий уход", image: parrotPhoto, petType: "Птица", careType: "Общий уход", readTime: "4 мин")
        ]
    }

    static var posts: [Post] {
        [
            Post(
                id: "p1",
                author: "Анна К.",
                avatar: womanAvatar,
                content: "Наш Барсик наконец-то научился подавать лапу! Три недели тренировок и мешок вкусняшек.",
                image: dogPhoto,
                likes: 24,
                comments: [
                    Comment(id: "c1", author: "Игорь М.", avatar: manAvatar, content: "Молодцы! Мы тоже учим команды, но пока безуспешно 😅", timestamp: "1 час назад")
                ],
                club: "Собаки",
                timestamp: "2 часа назад",
                liked: false
            ),
            Post(
                id: "p2",
                author: "Дмитрий С.",
                avatar: manAvatar,
                content: "Кто-нибудь сталкивался с тем, что кошка отказывается от нового корма?",
                image: nil,
                likes: 15,
                comments: [],
                club: "Кошки",
                timestamp: "5 часов назад",
                liked: false
            ),
            Post(
                id: "p3",
                author: "Мария Л.",
                avatar: womanAvatar,
                content: "Наш попугайчик Кеша выучил новое слово — «Привет»! 🦜",
                image: parrotPhoto,
                likes: 38,
                comments: [],
                club: "Птицы",
                timestamp: "1 день назад",
                liked: true
            )
        ]
    }

    static var user: UserProfile {
        UserProfile(
            username: "elena_pets",
            email: "elena@example.com",
            avatar: userAvatar,
            bio: "Люблю животных! Хозяйка Барона, Мурки и Кеши",
            petsCount: 3,
            postsCount: 0,
            joinDate: "Январь 2026"
        )
    }
}
