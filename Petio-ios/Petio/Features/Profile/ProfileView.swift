//
//  ProfileView.swift
//  Petio
//
//  Профиль пользователя: аватар, статистика, питомцы, посты/лайки, настройки.
//

import SwiftUI
import PhotosUI

enum ProfileTab: String, CaseIterable {
    case posts = "Мои посты"
    case liked = "Понравилось"
}

struct ProfileView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var authManager: AuthManager
    @State private var showEditProfile = false
    @State private var showLogoutAlert = false
    @State private var selectedTab: ProfileTab = .posts

    private var myPosts: [Post] {
        app.posts.filter { $0.author == app.user.username }
    }
    private var likedPosts: [Post] {
        app.posts.filter(\.liked)
    }
    private var displayPosts: [Post] {
        selectedTab == .posts ? myPosts : likedPosts
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                header
                tabs
                ScrollView(showsIndicators: false) {
                    profileContent
                }
            }
            .background(PetCareTheme.background)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .pets:
                    PetListViewModel()
                case .petDetail(let id):
                    PetDetailView(petId: id)
                case .health, .feed, .chat:
                    EmptyView()
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(user: app.user) { updated in
                    Task { await app.updateProfile(updated) }
                    showEditProfile = false
                } onCancel: { showEditProfile = false }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Профиль")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        showEditProfile = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .top, spacing: 12) {
                    AvatarPickerButton(
                        photoPath: Binding(
                            get: { app.user.avatar },
                            set: { newValue in
                                var updated = app.user
                                updated.avatar = newValue
                                Task { await app.updateProfile(updated) }
                            }
                        ),
                        placeholder: String(app.user.username.prefix(1)),
                        size: 64,
                        isCircle: true
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        if !app.user.username.isEmpty {
                            Text("@\(app.user.username)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        if let email = app.user.email, !email.isEmpty {
                            Text(email)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        if !app.user.bio.isEmpty {
                            Text(app.user.bio)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 8) {
                    statCard(icon: "pawprint", value: "\(app.pets.count)", label: "Питомцев")
                    statCard(icon: "square.and.pencil", value: "\(myPosts.count)", label: "Постов")
                    statCard(icon: "calendar", value: app.user.joinDate, label: "С нами с")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background {
                PetCareTheme.primary
                    .clipShape(
                        .rect(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 32,
                            bottomTrailingRadius: 32,
                            topTrailingRadius: 0
                        )
                    )
                    .ignoresSafeArea()
            }
        }
        .padding(.bottom, 16)
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.system(size: value.count > 3 ? 10 : 16, weight: .medium))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(ProfileTab.allCases, id: \.rawValue) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab == .posts ? "Мои посты (\(myPosts.count))" : "Понравилось (\(likedPosts.count))")
                        .font(.system(size: 14))
                        .foregroundColor(selectedTab == tab ? PetCareTheme.primary : PetCareTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedTab == tab ? Color.white : Color.clear)
                )
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(PetCareTheme.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var profileContent: some View {
        VStack(alignment: .leading, spacing: 16) {
//            myPetsSection
            postsList
            settingsSection
        }
        .padding(.bottom, 24)
    }

    private var myPetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(app.pets) { pet in
                        NavigationLink(value: AppRoute.petDetail(pet.id)) {
                            HStack(spacing: 8) {
                                AvatarView(url: pet.photo, placeholder: "🐾", size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pet.name)
                                        .font(.system(size: 14))
                                        .foregroundColor(PetCareTheme.primary)
                                    Text(pet.species)
                                        .font(.system(size: 10))
                                        .foregroundColor(PetCareTheme.muted)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .petCareCardStyle()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var postsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(displayPosts.enumerated()), id: \.element.id) { index, post in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        CircleAvatarView(url: post.avatar, fallbackLetter: String(post.author.prefix(1)), size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.author)
                                .font(.system(size: 13))
                                .foregroundColor(PetCareTheme.primary)
                            Text(post.timestamp)
                                .font(.system(size: 10))
                                .foregroundColor(PetCareTheme.muted)
                        }
                        Spacer()
                    }
                    Text(post.content)
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.primary)
                    HStack(spacing: 16) {
                        Label("\(post.likes)", systemImage: post.liked ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                            .foregroundColor(post.liked ? .red : PetCareTheme.muted)
                        Label("\(post.comments.count)", systemImage: "message")
                            .font(.system(size: 12))
                            .foregroundColor(PetCareTheme.muted)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .petCareCardStyle()
                .padding(.horizontal, 20)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.96)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(min(index, 8)) * 0.03), value: displayPosts.map(\.id))
            }
            if displayPosts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: selectedTab == .posts ? "square.and.pencil" : "heart")
                        .font(.system(size: 40))
                        .foregroundColor(PetCareTheme.primary.opacity(0.3))
                    Text(selectedTab == .posts ? "Вы ещё ничего не публиковали" : "Нет понравившихся постов")
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Настройки")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(PetCareTheme.primary)
                .padding(.horizontal, 20)
            VStack(spacing: 0) {
                settingsRow(icon: "bell", color: .blue, title: "Уведомления")
                settingsRow(icon: "lock.shield", color: .green, title: "Конфиденциальность")
                settingsRow(icon: "questionmark.circle", color: .orange, title: "Помощь")
                Divider().padding(.leading, 60)
                settingsRow(icon: "rectangle.portrait.and.arrow.right", color: .red, title: "Выйти") {
                    showLogoutAlert = true
                }
            }
            .alert("Выйти из аккаунта?", isPresented: $showLogoutAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти", role: .destructive) { authManager.deleteToken() }
            } message: {
                Text("Вы будете перенаправлены на экран входа.")
            }
            .petCareCardStyle()
            .padding(.horizontal, 20)
        }
    }

    private func settingsRow(icon: String, color: Color, title: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(title == "Выйти" ? .red : PetCareTheme.primary)
                Spacer()
                if title != "Выйти" {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(PetCareTheme.muted)
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

struct EditProfileSheet: View {
    let user: UserProfile
    let onSave: (UserProfile) -> Void
    let onCancel: () -> Void

    @State private var username: String = ""
    @State private var bio: String = ""

    private var isUsernameValid: Bool {
        username.trimmingCharacters(in: .whitespaces).isEmpty ||
        username.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 4) {
                        Text("@")
                            .foregroundColor(.secondary)
                        TextField("никнейм", text: $username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    if !isUsernameValid {
                        Text("Только буквы, цифры, - и _")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Никнейм")
                } footer: {
                    if username.isEmpty {
                        Text("Оставьте пустым — останется текущий ник")
                    }
                }
                Section("О себе") {
                    TextEditor(text: $bio)
                        .frame(minHeight: 80)
                }
            }
            .onAppear {
                username = user.username
                bio = user.bio
            }
            .navigationTitle("Редактировать профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        var u = user
                        u.bio = bio
                        let trimmed = username.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty && isUsernameValid {
                            u.username = trimmed
                        }
                        onSave(u)
                    }
                    .disabled(!isUsernameValid)
                }
            }
        }
    }
}
