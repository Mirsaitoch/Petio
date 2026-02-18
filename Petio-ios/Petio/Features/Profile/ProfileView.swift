//
//  ProfileView.swift
//  Petio
//
//  Профиль пользователя: аватар, статистика, питомцы, посты/лайки, настройки.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var app: AppState
    @State private var showEditProfile = false
    @State private var activeTab = "posts"

    private var myPosts: [Post] {
        app.posts.filter { $0.author == app.user.name }
    }
    private var likedPosts: [Post] {
        app.posts.filter(\.liked)
    }
    private var displayPosts: [Post] {
        activeTab == "posts" ? myPosts : likedPosts
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    myPetsSection
                    postTabs
                    postsList
                    settingsSection
                }
                .padding(.bottom, 24)
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
        ZStack(alignment: .bottomLeading) {
            PetCareGradientHeader(title: "Профиль") {
                Button {
                    showEditProfile = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 140)

            HStack(alignment: .top, spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    CircleAvatarView(
                        url: app.user.avatar,
                        fallbackLetter: String(app.user.name.prefix(1)),
                        size: 80
                    )
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.primary)
                        .frame(width: 28, height: 28)
                        .background(Color.white)
                        .clipShape(Circle())
                        .offset(x: 2, y: 2)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.user.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Text(app.user.username)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    Text(app.user.bio)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .padding(.top, 8)
        }
        .padding(.bottom, 8)

        return HStack(spacing: 12) {
            statCard(icon: "pawprint", value: "\(app.pets.count)", label: "Питомцев")
            statCard(icon: "square.and.pencil", value: "\(myPosts.count)", label: "Постов")
            statCard(icon: "calendar", value: app.user.joinDate, label: "С нами с")
        }
        .padding(.horizontal, 20)
        .padding(.top, -8)
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.system(size: value.count > 3 ? 11 : 18, weight: .medium))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var myPetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetCareSectionHeader(
                title: "Мои питомцы",
                actionTitle: "Все",
                action: { }
            )
            .padding(.horizontal, 20)
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
                            .background(PetCareTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(PetCareTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var postTabs: some View {
        HStack(spacing: 0) {
            Button {
                activeTab = "posts"
            } label: {
                Text("Мои посты (\(myPosts.count))")
                    .font(.system(size: 14))
                    .foregroundColor(activeTab == "posts" ? PetCareTheme.primary : PetCareTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(activeTab == "posts" ? Color.white : Color.clear)
            )
            .buttonStyle(.plain)
            Button {
                activeTab = "liked"
            } label: {
                Text("Понравилось (\(likedPosts.count))")
                    .font(.system(size: 14))
                    .foregroundColor(activeTab == "liked" ? PetCareTheme.primary : PetCareTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(activeTab == "liked" ? Color.white : Color.clear)
            )
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(PetCareTheme.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var postsList: some View {
        VStack(spacing: 12) {
            ForEach(displayPosts) { post in
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
            }
            if displayPosts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: activeTab == "posts" ? "square.and.pencil" : "heart")
                        .font(.system(size: 40))
                        .foregroundColor(PetCareTheme.primary.opacity(0.3))
                    Text(activeTab == "posts" ? "Вы ещё ничего не публиковали" : "Нет понравившихся постов")
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
                settingsRow(icon: "rectangle.portrait.and.arrow.right", color: .red, title: "Выйти")
            }
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(PetCareTheme.border, lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }

    private func settingsRow(icon: String, color: Color, title: String) -> some View {
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
}

struct EditProfileSheet: View {
    let user: UserProfile
    let onSave: (UserProfile) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var bio: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Имя") { TextField("Ваше имя", text: $name) }
                Section("О себе") {
                    TextEditor(text: $bio)
                        .frame(minHeight: 80)
                }
            }
            .onAppear {
                name = user.name
                bio = user.bio
            }
            .navigationTitle("Редактировать профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        var u = user
                        u.name = name
                        u.bio = bio
                        onSave(u)
                    }
                }
            }
        }
    }
}
