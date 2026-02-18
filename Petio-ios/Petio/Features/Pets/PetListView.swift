//
//  PetListView.swift
//  Petio
//
//  Список питомцев и добавление нового.
//

import SwiftUI

struct PetListViewModel: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showAddSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(app.pets) { pet in
                    NavigationLink(value: AppRoute.petDetail(pet.id)) {
                        PetListRow(pet: pet)
                    }
                    .buttonStyle(.plain)
                }
                PetCareDashedButton(title: "Добавить питомца") {
                    showAddSheet = true
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
        .background(PetCareTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Мои питомцы")
                    .font(.headline)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddPetSheet(onSave: { pet in
                Task { await app.addPet(pet) }
                showAddSheet = false
            }, onCancel: { showAddSheet = false })
        }
    }
}

struct PetListRow: View {
    let pet: Pet

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
        HStack(spacing: 16) {
            AvatarView(url: pet.photo, placeholder: speciesEmoji(pet.species), size: 80)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pet.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(PetCareTheme.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.muted)
                }
                Text(pet.breed)
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.muted)
                HStack(spacing: 12) {
                    Label(pet.age, systemImage: "calendar")
                    Label("\(pet.weight, specifier: "%.1f") кг", systemImage: "scalemass")
                    Label("\(pet.vaccinations.count)", systemImage: "shield")
                }
                .font(.system(size: 11))
                .foregroundColor(PetCareTheme.muted)
                if !pet.features.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(pet.features.prefix(2), id: \.self) { f in
                            Text(f)
                                .font(.system(size: 10))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(PetCareTheme.secondary)
                                .clipShape(Capsule())
                        }
                        if pet.features.count > 2 {
                            Text("+\(pet.features.count - 2)")
                                .font(.system(size: 10))
                                .foregroundColor(PetCareTheme.muted)
                        }
                    }
                }
            }
        }
        .padding(16)
        .petCareCardStyle()
        .padding(.horizontal, 20)
    }
}

struct AddPetSheet: View {
    let onSave: (Pet) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var species = "Собака"
    @State private var breed = ""
    @State private var age = ""
    @State private var weight = ""
    @State private var features = ""

    private let speciesList = ["Собака", "Кошка", "Птица", "Кролик", "Рыбка", "Другое"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Имя *") {
                    TextField("Введите имя", text: $name)
                }
                Section("Вид") {
                    Picker("Вид", selection: $species) {
                        ForEach(speciesList, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Section("Порода") { TextField("Порода", text: $breed) }
                Section("Возраст") { TextField("Напр.: 2 года", text: $age) }
                Section("Вес (кг)") {
                    TextField("0", text: $weight)
                        .keyboardType(.decimalPad)
                }
                Section("Особенности (через запятую)") {
                    TextField("Аллергия, любит играть...", text: $features)
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
                        let pet = Pet(
                            id: UUID().uuidString,
                            name: name.isEmpty ? "Питомец" : name,
                            species: species,
                            breed: breed.isEmpty ? "Не указана" : breed,
                            age: age.isEmpty ? "Неизвестно" : age,
                            weight: Double(weight) ?? 0,
                            photo: nil,
                            birthDate: "",
                            vaccinations: [],
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
