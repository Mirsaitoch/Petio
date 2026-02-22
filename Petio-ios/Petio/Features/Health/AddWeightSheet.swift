//
//  AddWeightSheet.swift
//  Petio
//

import SwiftUI

struct AddWeightSheet: View {
    let petId: String
    let onSave: (WeightRecord) -> Void
    let onCancel: () -> Void
    
    @State private var weight = ""
    @State private var date = "2026-02-17"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Вес (кг)") {
                    TextField("0", text: $weight)
                        .keyboardType(.decimalPad)
                }
                Section("Дата") { TextField("Дата", text: $date) }
            }
            .navigationTitle("Новая запись веса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        guard let w = Double(weight) else { return }
                        onSave(WeightRecord(date: date, weight: w))
                    }
                    .disabled(weight.isEmpty)
                }
            }
        }
    }
}
