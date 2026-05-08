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
    var authManager: AuthManager?
    let networkMonitor = NetworkMonitor()
    private var networkObserverTask: Task<Void, Never>?

    init(api: APIClientProtocol = MockAPIClient(), authManager: AuthManager? = nil) {
        self.api = api
        self.authManager = authManager
        self.customDiaryTags = LocalStorage.load(from: .tags) ?? []
        setupNetworkObserver()
    }

    private func setupNetworkObserver() {
        networkObserverTask = Task {
            for await isOnline in networkMonitor.$isOnline.values {
                if isOnline {
                    await syncAllData()
                }
            }
        }
    }

    deinit {
        networkObserverTask?.cancel()
    }

    private func syncAllData() async {
        guard authManager?.isAuthenticated == true else { return }
        print("✅ Сеть восстановлена, отправляю локальные данные на сервер...")
        await pushPetsToServer()
        await pushRemindersToServer()
        await pushDiaryToServer()
        print("✅ Локальные данные синхронизированы с сервером")
    }

    private func pushPetsToServer() async {
        for pet in pets {
            do {
                _ = try await api.updatePet(pet)
            } catch {
                _ = try? await api.addPet(pet)
            }
        }
    }

    private func pushRemindersToServer() async {
        for reminder in reminders {
            do {
                _ = try await api.addReminder(reminder)
            } catch {
                // reminder may already exist; ignore duplicate errors
            }
        }
    }

    private func pushDiaryToServer() async {
        for entry in diary {
            do {
                _ = try await api.addDiaryEntry(entry)
            } catch {
                // entry may already exist; ignore duplicate errors
            }
        }
    }

    func addCustomTag(_ tag: DiaryTag) {
        customDiaryTags.append(tag)
        saveCustomTags()
    }

    func removeCustomTag(id: String) {
        customDiaryTags.removeAll { $0.id == id }
        saveCustomTags()
    }

    var allDiaryTags: [DiaryTag] {
        DiaryTag.defaults + customDiaryTags
    }

    // MARK: - Data (published for UI)
    @Published var pets: [Pet] = []
    @Published var reminders: [Reminder] = []
    @Published var weightHistory: [String: [WeightRecord]] = [:]
    @Published var diary: [HealthDiaryEntry] = []
    @Published var articles: [Article] = []
    @Published var posts: [Post] = []
    @Published var isPostUploading = false
    @Published var postsLoadFailed = false
    @Published var chatMessages: [ChatMessage] = []
    @Published var currentChatId: String?
    @Published var user: UserProfile = UserProfile(name: "", username: "", avatar: nil, bio: "", petsCount: 0, postsCount: 0, joinDate: "")
    @Published var selectedPetId: String = ""
    @Published var customDiaryTags: [DiaryTag] = []
    @Published var selectedTab: AppTab = .home

    // MARK: - LocalStorage helpers

    private func savePets() {
        LocalStorage.save(pets, to: .pets)
    }

    private func saveDiary() {
        LocalStorage.save(diary, to: .diary)
    }

    private func saveWeightHistory() {
        LocalStorage.save(weightHistory, to: .weight)
    }

    private func saveCustomTags() {
        LocalStorage.save(customDiaryTags, to: .tags)
    }

    private func saveReminders() {
        LocalStorage.save(reminders, to: .reminders)
    }

    // MARK: - Load from API (business logic)
    func loadAll() async {
        print("[STATE] loadAll: Phase 1 starting")
        async let p: () = loadPets()
        async let r: () = loadReminders()
        async let a: () = loadArticles()
        async let po: () = loadPosts()
        async let u: () = loadProfile()
        _ = await (p, r, a, po, u)
        print("[STATE] loadAll: Phase 1 completed")

        if selectedPetId.isEmpty, let first = pets.first {
            selectedPetId = first.id
        }

        print("[STATE] loadAll: Phase 2 starting")
        async let w: () = loadWeightHistory()
        async let d: () = loadDiary()
        _ = await (w, d)
        print("[STATE] loadAll: Phase 2 completed")
    }

    func loadPets() async {
        if let saved: [Pet] = LocalStorage.load(from: .pets) {
            pets = saved
            return
        }
        guard authManager?.isAuthenticated == true else { return }
        do {
            let fetched = try await api.fetchPets()
            pets = fetched
            savePets()
        } catch {
            // keep current state on error
        }
    }

    func loadReminders() async {
        if let saved: [Reminder] = LocalStorage.load(from: .reminders) {
            reminders = saved
            return
        }
        guard authManager?.isAuthenticated == true else { return }
        do {
            reminders = try await api.fetchReminders(petId: nil)
            saveReminders()
        } catch {
            // keep current state on error
        }
    }

    func loadWeightHistory() async {
        if let saved: [String: [WeightRecord]] = LocalStorage.load(from: .weight) {
            weightHistory = saved
            for (petId, records) in weightHistory {
                if let latest = records.last, let i = pets.firstIndex(where: { $0.id == petId }) {
                    pets[i].weight = latest.weight
                }
            }
            return
        }
        guard authManager?.isAuthenticated == true else { return }
        for id in pets.map(\.id) {
            do {
                let list = try await api.fetchWeightHistory(petId: id)
                weightHistory[id] = list
                if let latest = list.last, let i = pets.firstIndex(where: { $0.id == id }) {
                    pets[i].weight = latest.weight
                }
            } catch {
                weightHistory[id] = weightHistory[id] ?? []
            }
        }
        saveWeightHistory()
    }

    func loadDiary() async {
        if let saved: [HealthDiaryEntry] = LocalStorage.load(from: .diary) {
            diary = saved
            return
        }
        guard authManager?.isAuthenticated == true, !pets.isEmpty else { return }
        var all: [HealthDiaryEntry] = []
        for id in pets.map(\.id) {
            if let entries = try? await api.fetchDiary(petId: id) {
                all.append(contentsOf: entries)
            }
        }
        diary = all
        saveDiary()
    }

    func loadArticles() async {
        do {
            articles = try await api.fetchArticles()
        } catch {
            // keep current state on error
        }
    }

    func loadPosts() async {
        postsLoadFailed = false
        print("[POSTS] loadPosts: начало загрузки")
        do {
            let response = try await api.fetchPosts(club: nil, limit: 20, afterID: nil, beforeID: nil)
            posts = response.posts
            print("[POSTS] loadPosts: загружено \(response.posts.count) постов")
        } catch {
            print("[POSTS] loadPosts: ошибка — \(error)")
            if posts.isEmpty {
                postsLoadFailed = true
                print("[POSTS] loadPosts: постов нет, postsLoadFailed=true")
            }
        }
    }

    func loadProfile() async {
        guard authManager?.isAuthenticated == true else {
            if let saved: UserProfile = LocalStorage.load(from: .profile) {
                print("[PROFILE] Гость: загружен из кеша — username='\(saved.username)'")
                user = saved
                return
            }
            let animals = ["cat", "dog", "fox", "owl", "bear", "wolf", "deer", "crow", "frog", "hawk"]
            let zoo = "\(animals.randomElement() ?? "pet")-\(Int.random(in: 10000...99999))"
            let guestProfile = UserProfile(name: "", username: zoo, avatar: nil, bio: "", petsCount: 0, postsCount: 0, joinDate: "")
            user = guestProfile
            LocalStorage.save(guestProfile, to: .profile)
            print("[PROFILE] Гость: создан новый — username='\(zoo)'")
            return
        }

        let savedUsername = UserDefaults.standard.string(forKey: "petio_session_username")
        print("[PROFILE] Авторизован. petio_session_username='\(savedUsername ?? "nil")'")

        if let cached: UserProfile = LocalStorage.load(from: .profile) {
            user = cached
            print("[PROFILE] Загружен кеш профиля — username='\(cached.username)'")
        }
        do {
            let profile = try await api.fetchProfile()
            print("[PROFILE] Ответ сервера — name='\(profile.name)', username='\(profile.username)', avatar='\(profile.avatar ?? "nil")'")

            var result = profile

            let usernameKey = "petio_session_username"
            var needsSyncUsername = false
            if result.username.trimmingCharacters(in: .whitespaces).isEmpty {
                if let saved = UserDefaults.standard.string(forKey: usernameKey) {
                    result.username = saved
                    print("[PROFILE] Username пустой на сервере, подставлен из UserDefaults: '\(saved)'")
                } else {
                    let animals = ["cat", "dog", "fox", "owl", "bear", "wolf", "deer", "crow", "frog", "hawk"]
                    let zoo = "\(animals.randomElement() ?? "pet")-\(Int.random(in: 10000...99999))"
                    UserDefaults.standard.set(zoo, forKey: usernameKey)
                    result.username = zoo
                    print("[PROFILE] Username пустой везде, сгенерирован новый: '\(zoo)'")
                }
                needsSyncUsername = true
            } else {
                UserDefaults.standard.set(result.username, forKey: usernameKey)
                print("[PROFILE] Username с сервера сохранён: '\(result.username)'")
            }

            user = result
            LocalStorage.save(result, to: .profile)
            print("[PROFILE] Итоговый профиль — name='\(result.name)', username='\(result.username)', email='\(result.email ?? "nil")'")

            if needsSyncUsername {
                print("[PROFILE] Синхронизация username на сервер: '\(result.username)'")
                try? await api.updateProfile(result)
            }
        } catch {
            print("[PROFILE] Ошибка загрузки профиля с сервера: \(error)")

            let usernameKey = "petio_session_username"
            let fallbackUsername = UserDefaults.standard.string(forKey: usernameKey) ?? ""

            if !fallbackUsername.isEmpty {
                let fallback = UserProfile(
                    name: user.name,
                    username: fallbackUsername,
                    avatar: nil,
                    bio: user.bio,
                    petsCount: pets.count,
                    postsCount: posts.count,
                    joinDate: ""
                )
                user = fallback
                LocalStorage.save(fallback, to: .profile)
                print("[PROFILE] Fallback профиль из UserDefaults — username='\(fallbackUsername)'")
            }
        }
    }

    func resetUserSession() {
        pets = []
        reminders = []
        weightHistory = [:]
        diary = []
        articles = []
        posts = []
        chatMessages = []
        currentChatId = nil
        customDiaryTags = []
        selectedPetId = ""
        user = UserProfile(name: "", username: "", avatar: nil, bio: "", petsCount: 0, postsCount: 0, joinDate: "")

        for file in StorageFile.allCases {
            LocalStorage.delete(file: file)
        }

        CacheManager().clearAll()

        UserDefaults.standard.removeObject(forKey: "petio_session_username")
    }

    // MARK: - Mutations (business logic → API, then update state)
    func addPet(_ pet: Pet) async {
        do {
            let added = try await api.addPet(pet)
            pets.append(added)
            if added.weight > 0 {
                let today = Self.dateString(from: Date())
                let weightRecord = WeightRecord(date: today, weight: added.weight)
                await addWeightRecord(petId: added.id, weightRecord)
            }
        } catch {
            pets.append(pet)
            if pet.weight > 0 {
                let today = Self.dateString(from: Date())
                let weightRecord = WeightRecord(date: today, weight: pet.weight)
                await addWeightRecord(petId: pet.id, weightRecord)
            }
        }
        savePets()
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
        savePets()
    }

    func deletePet(id: String) async {
        do {
            try await api.deletePet(id: id)
            pets.removeAll { $0.id == id }
        } catch {
            pets.removeAll { $0.id == id }
        }
        savePets()
    }

    func toggleReminder(id: String) {
        guard let i = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[i].completed.toggle()
        saveReminders()
    }

    func addReminder(_ reminder: Reminder) async {
        do {
            let added = try await api.addReminder(reminder)
            reminders.append(added)
        } catch {
            reminders.append(reminder)
        }
        saveReminders()
    }

    func updateReminder(_ reminder: Reminder) async {
        if let i = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[i] = reminder
        }
        do { _ = try await api.updateReminder(reminder) } catch {}
        saveReminders()
    }

    func deleteReminder(id: String) async {
        do {
            try await api.deleteReminder(id: id)
            reminders.removeAll { $0.id == id }
        } catch {
            reminders.removeAll { $0.id == id }
        }
        saveReminders()
    }

    func addWeightRecord(petId: String, _ record: WeightRecord) async {
        print("[WEIGHT] addWeightRecord: petId='\(petId)', date='\(record.date)', weight=\(record.weight)")
        guard !petId.isEmpty else {
            print("[WEIGHT] addWeightRecord: petId пустой, пропускаю")
            return
        }
        do {
            try await api.addWeightRecord(petId: petId, record)
            print("[WEIGHT] addWeightRecord: сервер OK")
        } catch {
            print("[WEIGHT] addWeightRecord: ошибка сервера — \(error), сохраняю локально")
        }
        var list = weightHistory[petId] ?? []
        list.append(record)
        list.sort { ($0.date).localizedStandardCompare($1.date) == .orderedAscending }
        weightHistory[petId] = list
        if let latest = list.last, let i = pets.firstIndex(where: { $0.id == petId }) {
            pets[i].weight = latest.weight
        }
        saveWeightHistory()
        savePets()
        print("[WEIGHT] addWeightRecord: сохранено, записей для petId=\(weightHistory[petId]?.count ?? 0)")
    }

    func addDiaryEntry(_ entry: HealthDiaryEntry) async {
        do {
            var added = try await api.addDiaryEntry(entry)
            added.tags = entry.tags
            diary.insert(added, at: 0)
        } catch {
            diary.insert(entry, at: 0)
        }
        saveDiary()
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
        saveDiary()
    }

    func deleteDiaryEntry(id: String) async {
        do {
            try await api.deleteDiaryEntry(id: id)
            diary.removeAll { $0.id == id }
        } catch {
            diary.removeAll { $0.id == id }
        }
        saveDiary()
    }

    func togglePostLike(postId: String) async {
        guard let i = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts[i].liked.toggle()
        posts[i].likes += posts[i].liked ? 1 : -1
        let newLiked = posts[i].liked
        do {
            try await api.likePost(id: postId, liked: newLiked)
        } catch {
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
            guard let j = posts.firstIndex(where: { $0.id == postId }) else { return }
            posts[j].comments.removeAll { $0.id == comment.id }
        }
    }

    func addPost(_ post: Post, image: UIImage? = nil) async {
        isPostUploading = image != nil
        defer { isPostUploading = false }
        print("[POSTS] addPost: author='\(post.author)', content='\(post.content.prefix(50))', hasImage=\(image != nil)")
        do {
            let added: Post
            if let image {
                let resized = resizedForUpload(image)
                if let imageData = resized.jpegData(compressionQuality: 0.7) {
                    print("[POSTS] addPost: загружаю изображение \(imageData.count) bytes")
                    added = try await api.addPostWithImage(post, imageData: imageData)
                    print("[POSTS] addPost: с изображением успех — image=\(added.image ?? "nil")")
                } else {
                    print("[POSTS] addPost: jpegData не удалось, отправляю без изображения")
                    added = try await api.addPost(post)
                }
            } else {
                added = try await api.addPost(post)
            }
            posts.insert(added, at: 0)
            print("[POSTS] addPost: добавлен в список, всего постов=\(posts.count)")
        } catch {
            print("[POSTS] addPost: ошибка — \(error), добавляю локально")
            posts.insert(post, at: 0)
        }
    }

    private func resizedForUpload(_ image: UIImage, maxDimension: CGFloat = 1080) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    func deletePost(id: String) {
        posts.removeAll { $0.id == id }
    }

    // MARK: - Chat (мульти-чат API)

    /// Отправить сообщение. Автоматически создаёт чат при первом вызове.
    func sendChatMessage(_ text: String) async {
        // Создаём чат если нет текущего
        if currentChatId == nil {
            do {
                let chat = try await api.createChat(title: "")
                currentChatId = chat.id
                print("[CHAT] Создан новый чат: \(chat.id)")
            } catch {
                let errorMsg = ChatMessage(id: UUID().uuidString, chatId: "", role: "assistant", content: "Не удалось создать чат. Попробуйте позже.")
                chatMessages.append(errorMsg)
                return
            }
        }

        guard let chatId = currentChatId else { return }

        let userMsg = ChatMessage(id: UUID().uuidString, chatId: chatId, role: "user", content: text)
        chatMessages.append(userMsg)

        do {
            let aiMsg = try await api.sendChatMessage(chatId: chatId, text: text)
            chatMessages.append(aiMsg)
        } catch {
            let errorMsg = ChatMessage(id: UUID().uuidString, chatId: chatId, role: "assistant", content: "Не удалось получить ответ. Попробуйте позже.")
            chatMessages.append(errorMsg)
        }
    }

    /// Загрузить историю сообщений текущего чата.
    func loadChatMessages() async {
        guard let chatId = currentChatId else { return }
        do {
            chatMessages = try await api.getChatMessages(chatId: chatId, limit: 50, offset: 0)
        } catch {
            print("[CHAT] Ошибка загрузки сообщений: \(error)")
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
        return reminders.filter {
            DateHelper.normalizeToDateOnly($0.date) <= today
        }.sorted { $0.date < $1.date }
    }

    func upcomingReminders() -> [Reminder] {
        let today = Self.dateString(from: Date())
        return reminders.filter {
            DateHelper.normalizeToDateOnly($0.date) > today
        }.prefix(3).map { $0 }
    }

    static func dateString(from date: Date) -> String {
        DateHelper.dateString(from: date)
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
