//
//  FeedView.swift
//  Petio
//

import SwiftUI

private let isoFormatters: [ISO8601DateFormatter] = {
    let withFrac = ISO8601DateFormatter()
    withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return [withFrac, plain]
}()

func parsePostDate(_ timestamp: String) -> Date? {
    isoFormatters.lazy.compactMap { $0.date(from: timestamp) }.first
}

struct FeedView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedClub = "Все"
    @State private var newestFirst = true
    @State private var showNewPost = false
    @State private var expandedComments: Set<String> = []
    @State private var commentText: [String: String] = [:]
    @State private var showAuthPrompt = false
    @State private var authPromptMessage = ""

    private let clubs = ["Все", "Собаки", "Кошки", "Птицы", "Кролики", "Экзотика"]

    private var filteredPosts: [Post] {
        let base = selectedClub == "Все" ? app.posts : app.posts.filter { $0.club == selectedClub }
        return base.sorted {
            let d0 = parsePostDate($0.timestamp) ?? .distantPast
            let d1 = parsePostDate($1.timestamp) ?? .distantPast
            return newestFirst ? d0 > d1 : d0 < d1
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if app.postsLoadFailed && app.posts.isEmpty {
                errorView
            } else {
                ChipGroup(
                    haveAdditionalPadding: true,
                    labels: clubs,
                    selection: $selectedClub
                )
                ScrollView(showsIndicators: false) {
                    feedContent
                }
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [PetCareTheme.background, PetCareTheme.background.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: Self.topFadeHeight)
                    .allowsHitTesting(false)
                }
            }
        }
        .background(PetCareTheme.background)
        .sheet(isPresented: $showAuthPrompt) {
            AuthPromptSheet(isPresented: $showAuthPrompt, message: authPromptMessage)
        }
        .sheet(isPresented: $showNewPost) {
            NewPostSheet(user: app.user) { post, image in
                Task {
                    await app.addPost(post, image: image)
                    showNewPost = false
                }
            } onCancel: { showNewPost = false }
        }
    }

    private var header: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Лента")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    newestFirst.toggle()
                } label: {
                    Image(systemName: newestFirst ? "arrow.down" : "arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    if authManager.isAuthenticated {
                        showNewPost = true
                    } else {
                        authPromptMessage = "Чтобы создавать посты, войдите в аккаунт - это бесплатно"
                        showAuthPrompt = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .background(PetCareTheme.primary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .padding(.bottom, 16)
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
        .padding(.bottom, 10)
    }

    private static let topFadeHeight: CGFloat = 10

    private var errorView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 56))
                .foregroundColor(PetCareTheme.muted.opacity(0.4))
            VStack(spacing: 8) {
                Text("Не удалось загрузить ленту")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
                Text("Проверьте подключение к интернету\nи попробуйте снова")
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.muted)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await app.loadPosts() }
            } label: {
                Label("Повторить", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(PetCareTheme.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var feedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Color.clear.frame(height: Self.topFadeHeight)
            ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
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
                        guard authManager.isAuthenticated else {
                            authPromptMessage = "Чтобы комментировать, войдите в аккаунт"
                            showAuthPrompt = true
                            return
                        }
                        let text = (commentText[post.id] ?? "").trimmingCharacters(in: .whitespaces)
                        guard !text.isEmpty else { return }
                        let c = Comment(
                            id: UUID().uuidString,
                            author: app.user.username,
                            avatar: app.user.avatar,
                            content: text,
                            timestamp: ISO8601DateFormatter().string(from: Date())
                        )
                        Task { await app.addComment(postId: post.id, c) }
                        commentText[post.id] = ""
                    },
                    onLike: {
                        guard authManager.isAuthenticated else {
                            authPromptMessage = "Чтобы лайкать посты, войдите в аккаунт"
                            showAuthPrompt = true
                            return
                        }
                        Task { await app.togglePostLike(postId: post.id) }
                    }
                )
                .padding(.horizontal, 20)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.96)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(min(index, 8)) * 0.03), value: filteredPosts.map(\.id))
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

            PetCareDashedButton(title: "Добавить пост", icon: "plus") {
                if authManager.isAuthenticated {
                    showNewPost = true
                } else {
                    authPromptMessage = "Чтобы создавать посты, войдите в аккаунт — это бесплатно"
                    showAuthPrompt = true
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 24)
    }
}
