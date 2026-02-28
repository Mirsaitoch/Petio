//
//  AppState.swift
//  Petio
//
//  Глобальное состояние приложения. Бизнес-логика обращается к API через сервисы; состояние хранится здесь для UI.
//

import SwiftUI

@MainActor
final class AppState: ObservableObject {
    private let api: APIClientProtocol
    init(api: APIClientProtocol = MockAPIClient()) {
        self.api = api
    }

    // MARK: - Data (published for UI)
    @Published var pets: [Pet] = []
    @Published var reminders: [Reminder] = []
    @Published var weightHistory: [String: [WeightRecord]] = [:]
    @Published var diary: [HealthDiaryEntry] = []
    @Published var articles: [Article] = []
    @Published var posts: [Post] = []
    @Published var chatMessages: [ChatMessage] = []
    @Published var user: UserProfile = UserProfile(username: "", email: nil, avatar: nil, bio: "", petsCount: 0, postsCount: 0, joinDate: "")
    @Published var selectedPetId: String = ""

    // MARK: - Load from API (business logic)
    func loadAll() async {
        async let p: () = loadPets()
        async let r: () = loadReminders()
        async let w: () = loadWeightHistory()
        async let d: () = loadDiary()
        async let a: () = loadArticles()
        async let po: () = loadPosts()
        async let u: () = loadProfile()
        _ = await (p, r, w, d, a, po, u)
        if selectedPetId.isEmpty, let first = pets.first {
            selectedPetId = first.id
        }
    }

    func loadPets() async {
        do {
            pets = try await api.fetchPets()
        } catch {
            // keep current state on error
        }
    }

    func loadReminders() async {
        do {
            reminders = try await api.fetchReminders(petId: nil)
        } catch {
            // keep current state on error
        }
    }

    func loadWeightHistory() async {
        for id in pets.map(\.id) {
            do {
                let list = try await api.fetchWeightHistory(petId: id)
                weightHistory[id] = list
            } catch {
                weightHistory[id] = weightHistory[id] ?? []
            }
        }
    }

    func loadDiary() async {
        guard !pets.isEmpty else { return }
        var all: [HealthDiaryEntry] = []
        for id in pets.map(\.id) {
            if let entries = try? await api.fetchDiary(petId: id) {
                all.append(contentsOf: entries)
            }
        }
        diary = all
    }

    func loadArticles() async {
        do {
            articles = try await api.fetchArticles()
        } catch {
            // keep current state on error
        }
    }

    func loadPosts() async {
        do {
            posts = try await api.fetchPosts(club: nil)
        } catch {
            // keep current state on error
        }
    }

    func loadProfile() async {
        do {
            var profile = try await api.fetchProfile()

            // Подставляем email из сессии, если сервер не вернул
            if (profile.email ?? "").isEmpty,
               let savedEmail = UserDefaults.standard.string(forKey: "petio_session_email") {
                profile.email = savedEmail
            }

            // Подставляем username из сессии, если сервер не вернул
            if profile.username.trimmingCharacters(in: .whitespaces).isEmpty {
                let key = "petio_session_username"
                if let savedUsername = UserDefaults.standard.string(forKey: key) {
                    profile.username = savedUsername
                } else {
                    let animals = ["cat", "dog", "fox", "owl", "bear", "wolf", "deer", "crow", "frog", "hawk"]
                    let zoo = "\(animals.randomElement() ?? "pet")-\(Int.random(in: 10000...99999))"
                    UserDefaults.standard.set(zoo, forKey: key)
                    profile.username = zoo
                }
            }

            // Дефолтная аватарка
            if profile.avatar == nil {
                let key = "petio_user_default_avatar"
                if let saved = UserDefaults.standard.string(forKey: key) {
                    profile.avatar = saved
                } else {
                    let avatar = "ava_\(Int.random(in: 1...9))"
                    UserDefaults.standard.set(avatar, forKey: key)
                    profile.avatar = avatar
                }
            }

            user = profile
        } catch {
            // keep current state on error
        }
    }

    func resetUserSession() {
        user = UserProfile(username: "", email: nil, avatar: nil, bio: "", petsCount: 0, postsCount: 0, joinDate: "")
        pets = []
        reminders = []
        posts = []
        chatMessages = []
        UserDefaults.standard.removeObject(forKey: "petio_user_default_avatar")
        UserDefaults.standard.removeObject(forKey: "petio_session_email")
        UserDefaults.standard.removeObject(forKey: "petio_session_username")
    }

    // MARK: - Mutations (business logic → API, then update state)
    func addPet(_ pet: Pet) async {
        do {
            let added = try await api.addPet(pet)
            pets.append(added)
        } catch {
            pets.append(pet)
        }
    }

    func updatePet(_ pet: Pet) async {
        do {
            let updated = try await api.updatePet(pet)
            if let i = pets.firstIndex(where: { $0.id == updated.id }) {
                pets[i] = updated
            }
        } catch {
            if let i = pets.firstIndex(where: { $0.id == pet.id }) {
                pets[i] = pet
            }
        }
    }

    func deletePet(id: String) async {
        do {
            try await api.deletePet(id: id)
            pets.removeAll { $0.id == id }
        } catch {
            pets.removeAll { $0.id == id }
        }
    }

    func toggleReminder(id: String) {
        guard let i = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[i].completed.toggle()
    }

    func addReminder(_ reminder: Reminder) async {
        do {
            let added = try await api.addReminder(reminder)
            reminders.append(added)
        } catch {
            reminders.append(reminder)
        }
    }

    func deleteReminder(id: String) async {
        do {
            try await api.deleteReminder(id: id)
            reminders.removeAll { $0.id == id }
        } catch {
            reminders.removeAll { $0.id == id }
        }
    }

    func addWeightRecord(petId: String, _ record: WeightRecord) async {
        var list = weightHistory[petId] ?? []
        list.append(record)
        list.sort { ($0.date).localizedStandardCompare($1.date) == .orderedAscending }
        weightHistory[petId] = list
    }

    func addDiaryEntry(_ entry: HealthDiaryEntry) async {
        do {
            let added = try await api.addDiaryEntry(entry)
            diary.insert(added, at: 0)
        } catch {
            diary.insert(entry, at: 0)
        }
    }

    func updateDiaryEntry(_ entry: HealthDiaryEntry) async {
        do {
            try await api.updateDiaryEntry(entry)
            if let i = diary.firstIndex(where: { $0.id == entry.id }) {
                diary[i] = entry
            }
        } catch {
            if let i = diary.firstIndex(where: { $0.id == entry.id }) {
                diary[i] = entry
            }
        }
    }

    func deleteDiaryEntry(id: String) async {
        do {
            try await api.deleteDiaryEntry(id: id)
            diary.removeAll { $0.id == id }
        } catch {
            diary.removeAll { $0.id == id }
        }
    }

    func togglePostLike(postId: String) async {
        guard let i = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts[i].liked.toggle()
        posts[i].likes += posts[i].liked ? 1 : -1
        let newLiked = posts[i].liked
        do {
            try await api.likePost(id: postId, liked: newLiked)
        } catch {
            // revert optimistic update on error
            guard let j = posts.firstIndex(where: { $0.id == postId }) else { return }
            posts[j].liked.toggle()
            posts[j].likes += posts[j].liked ? 1 : -1
        }
    }

    func addComment(postId: String, _ comment: Comment) async {
        guard let i = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts[i].comments.append(comment)
        do {
            try await api.addComment(postId: postId, comment)
        } catch {
            // revert optimistic update on error
            guard let j = posts.firstIndex(where: { $0.id == postId }) else { return }
            posts[j].comments.removeAll { $0.id == comment.id }
        }
    }

    func addPost(_ post: Post) async {
        do {
            let added = try await api.addPost(post)
            posts.insert(added, at: 0)
        } catch {
            posts.insert(post, at: 0)
        }
    }

    func deletePost(id: String) {
        posts.removeAll { $0.id == id }
    }

    func sendChatMessage(_ text: String) async {
        let userMsg = ChatMessage(id: UUID().uuidString, role: .user, content: text, timestamp: Date())
        chatMessages.append(userMsg)
        do {
            let reply = try await api.sendChatMessage(text)
            let aiMsg = ChatMessage(id: UUID().uuidString, role: .assistant, content: reply, timestamp: Date())
            chatMessages.append(aiMsg)
        } catch {
            chatMessages.append(ChatMessage(id: UUID().uuidString, role: .assistant, content: "Не удалось получить ответ. Попробуйте позже.", timestamp: Date()))
        }
    }

    func updateProfile(_ profile: UserProfile) async {
        do {
            user = try await api.updateProfile(profile)
        } catch {
            user = profile
        }
    }

    // MARK: - Derived
    var selectedPet: Pet? {
        pets.first { $0.id == selectedPetId } ?? pets.first
    }

    func todayReminders() -> [Reminder] {
        let today = Self.dateString(from: Date())
        return reminders.filter { $0.date == today }
    }

    func upcomingReminders() -> [Reminder] {
        let today = Self.dateString(from: Date())
        return reminders.filter { $0.date > today }.prefix(3).map { $0 }
    }

    private static func dateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    func reminders(forPetId id: String, typeFilter: String?) -> [Reminder] {
        var list = reminders.filter { $0.petId == id }
        if let typeFilter = typeFilter, typeFilter != "all", let t = ReminderType(rawValue: typeFilter) {
            list = list.filter { $0.type == t }
        }
        return list
    }

    func diary(forPetId id: String) -> [HealthDiaryEntry] {
        diary.filter { $0.petId == id }
    }

    func weightRecords(forPetId id: String) -> [WeightRecord] {
        weightHistory[id] ?? []
    }
}
