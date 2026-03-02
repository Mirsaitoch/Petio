//
//  PetListView.swift
//  Petio
//
//  Список питомцев и добавление нового.
//

import SwiftUI
import PhotosUI

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
