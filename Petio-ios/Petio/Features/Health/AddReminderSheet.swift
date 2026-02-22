//
//  AddReminderSheet.swift
//  Petio
//

import SwiftUI

struct AddReminderSheet: View {
    let selectedPetId: String
    let pets: [Pet]
    let onSave: (Reminder) -> Void
    let onCancel: () -> Void
    
    @State private var type: ReminderType = .feeding
    @State private var title = ""
    @State private var date = "2026-02-17"
    @State private var time = "08:00"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Тип") {
                    Picker("Тип", selection: $type) {
                        ForEach(ReminderType.allCases, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Название") {
                    TextField("Например: Утреннее кормление", text: $title)
                }
                Section("Дата") { TextField("Дата", text: $date) }
                Section("Время") { TextField("Время", text: $time) }
            }
            .navigationTitle("Новое напоминание")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        let petName = pets.first(where: { $0.id == selectedPetId })?.name ?? ""
                        let r = Reminder(
                            id: UUID().uuidString,
                            petId: selectedPetId,
                            petName: petName,
                            type: type,
                            title: title.isEmpty ? type.label : title,
                            date: date,
                            time: time,
                            completed: false
                        )
                        onSave(r)
                    }
                }
            }
        }
    }
}
