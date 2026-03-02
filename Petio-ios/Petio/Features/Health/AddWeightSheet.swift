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
    @State private var date = Date()

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Вес (кг)") {
                    TextField("0", text: $weight)
                        .keyboardType(.decimalPad)
                }
                Section("Дата") {
                    DatePicker("Дата", selection: $date, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
            .navigationTitle("Новая запись веса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        guard let w = Double(weight) else { return }
                        onSave(WeightRecord(date: AddWeightSheet.isoFormatter.string(from: date), weight: w))
                    }
                    .disabled(weight.isEmpty)
                }
            }
        }
    }
}
