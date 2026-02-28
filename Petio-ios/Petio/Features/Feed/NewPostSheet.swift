//
//  NewPostSheet.swift
//  Petio
//
//  Шит создания нового поста: выбор клуба, текст, фото.
//

import SwiftUI

struct NewPostSheet: View {
    let user: UserProfile
    let onSave: (Post, UIImage?) -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var app: AppState

    @State private var content = ""
    @State private var club = "Собаки"
    @State private var selectedImage: UIImage?
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
                Section("Фото (необязательно)") {
                    PostImagePickerButton(selectedImage: $selectedImage)
                }
            }
            .navigationTitle("Новый пост")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                        .disabled(app.isPostUploading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if app.isPostUploading {
                        ProgressView()
                    } else {
                        Button("Опубликовать") {
                            let post = Post(
                                id: UUID().uuidString,
                                author: user.username,
                                avatar: user.avatar,
                                content: content,
                                image: nil,
                                likes: 0,
                                comments: [],
                                club: club,
                                timestamp: ISO8601DateFormatter().string(from: Date()),
                                liked: false
                            )
                            onSave(post, selectedImage)
                        }
                        .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}
