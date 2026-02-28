//
//  PostCard.swift
//  Petio
//
//  Карточка поста в ленте: автор, контент, изображение, лайки, комментарии.
//

import SwiftUI

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
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    case .failure:
                        Color(PetCareTheme.border)
                            .frame(height: 180)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundColor(PetCareTheme.muted)
                            )
                    default:
                        Color(PetCareTheme.border)
                            .frame(height: 180)
                            .overlay(ProgressView())
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
