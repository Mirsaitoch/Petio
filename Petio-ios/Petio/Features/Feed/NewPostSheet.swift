//
//  NewPostSheet.swift
//  Petio
//
//  Шит создания нового поста: выбор клуба, текст.
//

import SwiftUI

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
                            author: user.username,
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
