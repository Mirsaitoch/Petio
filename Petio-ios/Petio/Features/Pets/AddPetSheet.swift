//
//  AddPetSheet.swift
//  Petio
//
//  Created by Мирсаит Сабирзянов on 02.03.2026.
//

import SwiftUI

struct AddPetSheet: View {
    let onSave: (Pet) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var species = "Собака"
    @State private var customSpecies = ""
    @State private var breed = ""
    @State private var birthDate = Date()
    @State private var weight = ""
    @State private var features = ""
    @State private var photoPath: String? = nil

    private let speciesList = ["Собака", "Кошка", "Птица", "Кролик", "Рыбка", "Другое"]
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private func speciesEmoji(_ s: String) -> String {
        switch s {
        case "Собака": return "🐕"
        case "Кошка": return "🐱"
        case "Птица": return "🦜"
        case "Кролик": return "🐰"
        default: return "🐾"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    AvatarPickerButton(
                        photoPath: $photoPath,
                        placeholder: speciesEmoji(species),
                        size: 88
                    )
                    Text("Нажмите чтобы добавить фото")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(UIColor.systemGroupedBackground))

                Form {
                    Section("Имя *") {
                        TextField("Введите имя", text: $name)
                    }
                    Section("Вид") {
                        Picker("Вид", selection: $species) {
                            ForEach(speciesList, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        if species == "Другое" {
                            TextField("Укажите вид", text: $customSpecies)
                        }
                    }
                    Section("Порода") { TextField("Порода", text: $breed) }
                    Section("Дата рождения") {
                        DatePicker(
                            "Дата рождения",
                            selection: $birthDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }
                    Section("Вес (кг)") {
                        TextField("0", text: $weight)
                            .keyboardType(.decimalPad)
                            .onChange(of: weight) { _, newValue in
                                if let d = Double(newValue), d < 0 { weight = "" }
                            }
                    }
                    Section("Особенности (через запятую)") {
                        TextField("Аллергия, любит играть...", text: $features)
                    }
                }
            }
            .navigationTitle("Новый питомец")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        let birthString = AddPetSheet.isoFormatter.string(from: birthDate)
                        let trimmedCustom = customSpecies.trimmingCharacters(in: .whitespaces)
                        let finalSpecies = species == "Другое"
                            ? (trimmedCustom.isEmpty ? "Другое" : trimmedCustom)
                            : species
                        let pet = Pet(
                            id: UUID().uuidString,
                            name: name.isEmpty ? "Питомец" : name,
                            species: finalSpecies,
                            breed: breed.isEmpty ? "Не указана" : breed,
                            age: PetAgeCalculator.computedAge(from: birthString),
                            weight: max(0, Double(weight) ?? 0),
                            photo: photoPath,
                            birthDate: birthString,
                            vaccinations: [],
                            treatments: [],
                            features: features.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        )
                        onSave(pet)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
