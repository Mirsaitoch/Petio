//
//  PetDetailView.swift
//  Petio
//
//  Карточка питомца: фото, инфо, особенности, прививки.
//

import SwiftUI

struct PetDetailView: View {
    let petId: String
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    private var pet: Pet? {
        app.pets.first { $0.id == petId }
    }

    private func speciesEmoji(_ s: String) -> String {
        switch s {
        case "Собака": return "🐕"
        case "Кошка": return "🐱"
        case "Птица": return "🦜"
        default: return "🐾"
        }
    }
    var body: some View {
        Group {
            if let pet = pet {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroSection(pet: pet)
                        infoCards(pet: pet)
                        featuresSection(pet: pet)
                        vaccinationsSection(pet: pet)
                        healthLink
                    }
                    .padding(.bottom, 24)
                }
            }
//            else {
//                ContentUnavailableView("Питомец не найден", systemImage: "pawprint") {
//                    Button("Назад к списку") { dismiss() }
//                }
//            }
        }
        .background(PetCareTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Button { showEditSheet = true } label: {
                        Image(systemName: "pencil")
                    }
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let p = pet {
                EditPetSheet(pet: p) { updated in
                    Task { await app.updatePet(updated) }
                    showEditSheet = false
                } onCancel: { showEditSheet = false }
            }
        }
        .alert("Удалить \(pet?.name ?? "")?", isPresented: $showDeleteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                Task {
                    await app.deletePet(id: petId)
                    dismiss()
                }
            }
        } message: {
            Text("Все данные питомца будут удалены. Это действие нельзя отменить.")
        }
    }

    private func heroSection(pet: Pet) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let url = pet.photo, let u = URL(string: url) {
                AsyncImage(url: u) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(PetCareTheme.secondary)
                            .overlay(Text(speciesEmoji(pet.species)).font(.system(size: 60)))
                    }
                }
                .frame(height: 220)
                .clipped()
            } else {
                Rectangle()
                    .fill(PetCareTheme.secondary)
                    .frame(height: 220)
                    .overlay(Text(speciesEmoji(pet.species)).font(.system(size: 60)))
            }
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
                .frame(maxHeight: .infinity, alignment: .bottom)
            if pet.photo != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                    Text(pet.breed)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 0)
        .padding(.bottom, pet.photo == nil ? 0 : 0)
        .overlay(alignment: .topLeading) {
            if pet.photo == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(PetCareTheme.primary)
                    Text(pet.breed)
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.muted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
    }

    private func infoCards(pet: Pet) -> some View {
        HStack(spacing: 12) {
            PetCareInfoCard(icon: "calendar", value: pet.age, label: "Возраст", color: .blue)
            PetCareInfoCard(icon: "scalemass", value: "\(pet.weight) кг", label: "Вес", color: .orange)
            PetCareInfoCard(icon: "shield", value: "\(pet.vaccinations.count)", label: "Прививки", color: PetCareTheme.primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func featuresSection(pet: Pet) -> some View {
        Group {
            if !pet.features.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Особенности", systemImage: "star")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PetCareTheme.primary)
                    FlowLayout(spacing: 8) {
                        ForEach(pet.features, id: \.self) { f in
                            Text(f)
                                .font(.system(size: 13))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(PetCareTheme.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(20)
                .padding(.top, 8)
            }
        }
    }

    private func vaccinationsSection(pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Прививки", systemImage: "syringe")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PetCareTheme.primary)
            if pet.vaccinations.isEmpty {
                Text("Прививки не добавлены")
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .petCareCardStyle()
            } else {
                ForEach(pet.vaccinations) { v in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(v.name)
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("Активна")
                                .font(.system(size: 11))
                                .foregroundColor(PetCareTheme.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(PetCareTheme.primary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        HStack(spacing: 16) {
                            Text("Дата: \(v.date)")
                            Text("Следующая: \(v.nextDate)")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(PetCareTheme.muted)
                    }
                    .padding(14)
                    .petCareCardStyle()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var healthLink: some View {
        NavigationLink(value: AppRoute.health) {
            HStack {
                Text("Перейти к мониторингу здоровья")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(PetCareTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, p) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

struct EditPetSheet: View {
    let pet: Pet
    let onSave: (Pet) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var breed: String = ""
    @State private var age: String = ""
    @State private var weight: Double = 0
    @State private var featuresText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Имя") { TextField("Имя", text: $name) }
                Section("Порода") { TextField("Порода", text: $breed) }
                Section("Возраст") { TextField("Возраст", text: $age) }
                Section("Вес (кг)") {
                    TextField("Вес", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section("Особенности (через запятую)") {
                    TextField("Особенности", text: $featuresText)
                }
            }
            .onAppear {
                name = pet.name
                breed = pet.breed
                age = pet.age
                weight = pet.weight
                featuresText = pet.features.joined(separator: ", ")
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        var p = pet
                        p.name = name
                        p.breed = breed
                        p.age = age
                        p.weight = weight
                        p.features = featuresText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        onSave(p)
                    }
                }
            }
        }
    }
}
