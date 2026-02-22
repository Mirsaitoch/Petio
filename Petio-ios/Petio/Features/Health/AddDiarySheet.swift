//
//  AddDiarySheet.swift
//  Petio
//

import SwiftUI

struct AddDiarySheet: View {
    let petId: String
    let onSave: (HealthDiaryEntry) -> Void
    let onCancel: () -> Void
    
    @State private var note = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Заметка") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let e = HealthDiaryEntry(
                            id: UUID().uuidString,
                            petId: petId,
                            date: "2026-02-17",
                            note: note
                        )
                        onSave(e)
                    }
                    .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
