//
//  FeedView.swift
//  Petio
//
//  Лента постов по клубам, лайки, комментарии.
//

import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var app: AppState
    @State private var selectedClub = "Все"
    @State private var showNewPost = false
    @State private var expandedComments: Set<String> = []
    @State private var commentText: [String: String] = [:]

    private let clubs = ["Все", "Собаки", "Кошки", "Птицы", "Кролики", "Экзотика"]
    private var filteredPosts: [Post] {
        if selectedClub == "Все" { return app.posts }
        return app.posts.filter { $0.club == selectedClub }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                clubChips
                postsList
            }
            .padding(.bottom, 24)
        }
        .background(PetCareTheme.background)
        .sheet(isPresented: $showNewPost) {
            NewPostSheet(user: app.user) { post in
                Task { await app.addPost(post) }
                showNewPost = false
            } onCancel: { showNewPost = false }
        }
    }

    private var header: some View {
        PetCareGradientHeader(title: "Лента", subtitle: "Делитесь опытом с другими владельцами") {
            Button {
                showNewPost = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }

    private var clubChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(clubs, id: \.self) { club in
                    Button {
                        selectedClub = club
                    } label: {
                        Text(club)
                            .font(.system(size: 12))
                            .foregroundColor(selectedClub == club ? .white : PetCareTheme.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .background(
                        Capsule()
                            .fill(selectedClub == club ? PetCareTheme.primary : PetCareTheme.secondary)
                    )
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var postsList: some View {
        VStack(spacing: 16) {
            ForEach(filteredPosts) { post in
                PostCard(
                    post: post,
                    isCommentsExpanded: expandedComments.contains(post.id),
                    commentText: Binding(
                        get: { commentText[post.id] ?? "" },
                        set: { commentText[post.id] = $0 }
                    ),
                    onToggleComments: {
                        if expandedComments.contains(post.id) {
                            expandedComments.remove(post.id)
                        } else {
                            expandedComments.insert(post.id)
                        }
                    },
                    onSendComment: {
                        let text = (commentText[post.id] ?? "").trimmingCharacters(in: .whitespaces)
                        guard !text.isEmpty else { return }
                        let c = Comment(
                            id: UUID().uuidString,
                            author: app.user.name,
                            avatar: app.user.avatar,
                            content: text,
                            timestamp: "Только что"
                        )
                        app.addComment(postId: post.id, c)
                        commentText[post.id] = ""
                    },
                    onLike: { app.togglePostLike(postId: post.id) }
                )
            }
            if filteredPosts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "message")
                        .font(.system(size: 48))
                        .foregroundColor(PetCareTheme.primary.opacity(0.3))
                    Text("Пока нет публикаций")
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct PostCard: View {
    let post: Post
    let isCommentsExpanded: Bool
    @Binding var commentText: String
    let onToggleComments: () -> Void
    let onSendComment: () -> Void
    let onLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                CircleAvatarView(url: post.avatar, fallbackLetter: String(post.author.prefix(1)), size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(PetCareTheme.primary)
                    HStack(spacing: 6) {
                        Text(post.club)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PetCareTheme.secondary)
                            .clipShape(Capsule())
                        Text(post.timestamp)
                            .font(.system(size: 10))
                            .foregroundColor(PetCareTheme.muted)
                    }
                }
                Spacer()
            }
            .padding(16)

            Text(post.content)
                .font(.system(size: 14))
                .foregroundColor(PetCareTheme.primary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            if let urlString = post.image, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            HStack(spacing: 20) {
                Button(action: onLike) {
                    HStack(spacing: 6) {
                        Image(systemName: post.liked ? "heart.fill" : "heart")
                            .foregroundColor(post.liked ? .red : PetCareTheme.muted)
                        Text("\(post.likes)")
                            .font(.system(size: 14))
                            .foregroundColor(post.liked ? .red : PetCareTheme.muted)
                    }
                }
                .buttonStyle(.plain)
                Button(action: onToggleComments) {
                    HStack(spacing: 6) {
                        Image(systemName: "message")
                            .foregroundColor(PetCareTheme.muted)
                        Text("\(post.comments.count)")
                            .font(.system(size: 14))
                            .foregroundColor(PetCareTheme.muted)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(PetCareTheme.border.opacity(0.3))

            if isCommentsExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(post.comments) { c in
                        HStack(alignment: .top, spacing: 8) {
                            CircleAvatarView(url: c.avatar, fallbackLetter: String(c.author.prefix(1)), size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.author)
                                    .font(.system(size: 11))
                                    .foregroundColor(PetCareTheme.primary)
                                Text(c.content)
                                    .font(.system(size: 12))
                                    .foregroundColor(PetCareTheme.primary)
                            }
                            Spacer()
                            Text(c.timestamp)
                                .font(.system(size: 10))
                                .foregroundColor(PetCareTheme.muted)
                        }
                        .padding(8)
                        .background(PetCareTheme.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    HStack(spacing: 8) {
                        TextField("Ваш комментарий...", text: $commentText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                        Button(action: onSendComment) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(PetCareTheme.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .background(PetCareTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(PetCareTheme.border, lineWidth: 1))
    }
}

struct NewPostSheet: View {
    let user: UserProfile
    let onSave: (Post) -> Void
    let onCancel: () -> Void

    @State private var content = ""
    @State private var club = "Собаки"
    private let clubs = ["Собаки", "Кошки", "Птицы", "Кролики", "Экзотика"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Клуб") {
                    Picker("Клуб", selection: $club) {
                        ForEach(clubs, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Section("Текст") {
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Новый пост")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Опубликовать") {
                        let post = Post(
                            id: UUID().uuidString,
                            author: user.name,
                            avatar: user.avatar,
                            content: content,
                            image: nil,
                            likes: 0,
                            comments: [],
                            club: club,
                            timestamp: "Только что",
                            liked: false
                        )
                        onSave(post)
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
