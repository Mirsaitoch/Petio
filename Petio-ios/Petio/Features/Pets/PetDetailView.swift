//
//  PetDetailView.swift
//  Petio
//
//  Карточка питомца: фото, инфо, особенности, прививки.
//

import SwiftUI
import PhotosUI

struct PetDetailView: View {
    let petId: String
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showAddVaccinationSheet = false
    @State private var showAddTreatmentSheet = false

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
                        treatmentsSection(pet: pet)
                        healthLink
                    }
                    .padding(.bottom, 24)
                }
            } else {
                ContentUnavailableView("Питомец не найден", systemImage: "pawprint")
            }
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
        .sheet(isPresented: $showAddVaccinationSheet) {
            if let p = pet {
                AddVaccinationSheet { vaccination in
                    Task {
                        var updated = p
                        updated.vaccinations.append(vaccination)
                        await app.updatePet(updated)
                    }
                    showAddVaccinationSheet = false
                } onCancel: {
                    showAddVaccinationSheet = false
                }
            }
        }
        .sheet(isPresented: $showAddTreatmentSheet) {
            if let p = pet {
                AddTreatmentSheet { treatment in
                    Task {
                        var updated = p
                        updated.treatments.append(treatment)
                        await app.updatePet(updated)
                    }
                    showAddTreatmentSheet = false
                } onCancel: {
                    showAddTreatmentSheet = false
                }
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
            if let urlString = pet.photo {
                Group {
                    if urlString.hasPrefix("file://"),
                       let path = URL(string: urlString)?.path,
                       let uiImage = UIImage(contentsOfFile: path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let u = URL(string: urlString) {
                        AsyncImage(url: u) { phase in
                            if let img = phase.image {
                                img.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle()
                                    .fill(PetCareTheme.secondary)
                                    .overlay(Text(speciesEmoji(pet.species)).font(.system(size: 60)))
                            }
                        }
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
            HStack {
                Label("Прививки", systemImage: "syringe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
                Spacer()
                Button {
                    showAddVaccinationSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(PetCareTheme.primary)
                }
            }
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
                            Button {
                                Task {
                                    guard var p = app.pets.first(where: { $0.id == petId }) else { return }
                                    p.vaccinations.removeAll { $0.id == v.id }
                                    await app.updatePet(p)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                            }
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

    private func treatmentsSection(pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Обработки", systemImage: "cross.vial")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
                Spacer()
                Button {
                    showAddTreatmentSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(PetCareTheme.primary)
                }
            }
            if pet.treatments.isEmpty {
                Text("Обработки не добавлены")
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .petCareCardStyle()
            } else {
                ForEach(pet.treatments) { t in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.name)
                                .font(.system(size: 14, weight: .medium))
                            Text("Дата: \(t.date)")
                                .font(.system(size: 11))
                                .foregroundColor(PetCareTheme.muted)
                        }
                        Spacer()
                        Button {
                            Task {
                                guard var p = app.pets.first(where: { $0.id == petId }) else { return }
                                p.treatments.removeAll { $0.id == t.id }
                                await app.updatePet(p)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                        }
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

    private let speciesList = ["Собака", "Кошка", "Птица", "Кролик", "Рыбка", "Другое"]

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    @State private var name: String = ""
    @State private var species: String = "Собака"
    @State private var customSpecies: String = ""
    @State private var breed: String = ""
    @State private var birthDate: Date = Date()
    @State private var weight: Double = 0
    @State private var featuresText: String = ""
    @State private var photoPath: String? = nil

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
                        placeholder: speciesEmoji(pet.species),
                        size: 88
                    )
                    Text("Нажмите чтобы изменить фото")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(UIColor.systemGroupedBackground))

                Form {
                    Section("Имя") { TextField("Имя", text: $name) }
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
                        TextField("Вес", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .onChange(of: weight) { _, newValue in
                                if newValue < 0 { weight = 0 }
                            }
                    }
                    Section("Особенности (через запятую)") {
                        TextField("Особенности", text: $featuresText)
                    }
                }
            }
            .onAppear {
                name = pet.name
                // If species is not in the predefined list (excluding "Другое"), treat as custom
                let knownSpecies = ["Собака", "Кошка", "Птица", "Кролик", "Рыбка"]
                if knownSpecies.contains(pet.species) {
                    species = pet.species
                } else {
                    species = "Другое"
                    customSpecies = pet.species
                }
                breed = pet.breed
                birthDate = EditPetSheet.isoFormatter.date(from: pet.birthDate) ?? Date()
                weight = pet.weight
                featuresText = pet.features.joined(separator: ", ")
                photoPath = pet.photo
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let birthString = EditPetSheet.isoFormatter.string(from: birthDate)
                        let trimmedCustom = customSpecies.trimmingCharacters(in: .whitespaces)
                        let finalSpecies = species == "Другое"
                            ? (trimmedCustom.isEmpty ? "Другое" : trimmedCustom)
                            : species
                        var p = pet
                        p.name = name
                        p.species = finalSpecies
                        p.breed = breed
                        p.birthDate = birthString
                        p.age = PetAgeCalculator.computedAge(from: birthString)
                        p.weight = max(0, weight)
                        p.photo = photoPath
                        p.features = featuresText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        onSave(p)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct AddVaccinationSheet: View {
    let onSave: (Vaccination) -> Void
    let onCancel: () -> Void

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    @State private var name = ""
    @State private var date = Date()
    @State private var nextDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Напр.: Бешенство, DHPP", text: $name)
                }
                Section("Дата прививки") {
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                Section("Следующая прививка") {
                    DatePicker("Дата", selection: $nextDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
            .navigationTitle("Новая прививка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        let v = Vaccination(
                            id: UUID().uuidString,
                            name: name.trimmingCharacters(in: .whitespaces),
                            date: AddVaccinationSheet.isoFormatter.string(from: date),
                            nextDate: AddVaccinationSheet.isoFormatter.string(from: nextDate)
                        )
                        onSave(v)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct AddTreatmentSheet: View {
    let onSave: (Treatment) -> Void
    let onCancel: () -> Void

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    @State private var name = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Напр.: Антипаразитарная обработка", text: $name)
                }
                Section("Дата") {
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
            .navigationTitle("Новая обработка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        let t = Treatment(
                            id: UUID().uuidString,
                            name: name.trimmingCharacters(in: .whitespaces),
                            date: AddTreatmentSheet.isoFormatter.string(from: date)
                        )
                        onSave(t)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
