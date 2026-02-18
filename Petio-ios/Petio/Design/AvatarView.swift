//
//  AvatarView.swift
//  Petio
//
//  Аватар: по URL, плейсхолдер с эмодзи/инициалами.
//

import SwiftUI

struct AvatarView: View {
    let url: String?
    let placeholder: String
    let size: CGFloat

    init(url: String?, placeholder: String = "🐾", size: CGFloat = 44) {
        self.url = url
        self.placeholder = placeholder
        self.size = size
    }

    var body: some View {
        Group {
            if let urlString = url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
    }

    private var placeholderView: some View {
        Text(placeholder)
            .font(.system(size: size * 0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PetCareTheme.secondary)
    }
}

struct CircleAvatarView: View {
    let url: String?
    let fallbackLetter: String
    let size: CGFloat

    init(url: String?, fallbackLetter: String = "?", size: CGFloat = 40) {
        self.url = url
        self.fallbackLetter = String((fallbackLetter.first ?? "?"))
        self.size = size
    }

    var body: some View {
        Group {
            if let urlString = url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallbackView: some View {
        Text(fallbackLetter)
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PetCareTheme.primary)
    }
}
