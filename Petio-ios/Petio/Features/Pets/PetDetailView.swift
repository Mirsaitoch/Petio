//
//  PetDetailView.swift
//  Petio
//

import SwiftUI
import PhotosUI

struct PetDetailView: View {
    let petId: String
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showAddVaccinationSheet = false
    @State private var showAddTreatmentSheet = false
    @State private var offlineAlertMessage = ""
    @State private var showOfflineAlert = false

    private var pet: Pet? { app.pets.first { $0.id == petId } }

    var body: some View {
        Group {
            if let pet {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        heroSection(pet: pet)
                        infoSection(pet: pet)
                        if !pet.features.isEmpty { featuresSection(pet: pet) }
                        vaccinationsSection(pet: pet)
                        treatmentsSection(pet: pet)
                        healthLinkButton
                    }
                    .padding(.bottom, 32)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PetCareTheme.primary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 4) {
                    Button {
                        guard networkMonitor.isOnline else {
                            offlineAlertMessage = "Редактирование недоступно без интернета"
                            showOfflineAlert = true
                            return
                        }
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15))
                            .foregroundColor(networkMonitor.isOnline ? PetCareTheme.primary : PetCareTheme.muted)
                            .frame(width: 32, height: 32)
                            .background(PetCareTheme.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(!networkMonitor.isOnline)

                    Button(role: .destructive) {
                        guard networkMonitor.isOnline else {
                            offlineAlertMessage = "Удаление недоступно без интернета"
                            showOfflineAlert = true
                            return
                        }
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundColor(networkMonitor.isOnline ? .red : PetCareTheme.muted)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(!networkMonitor.isOnline)
                }
            }
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
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
                AddVaccinationSheet { vac in
                    Task {
                        var updated = p
                        updated.vaccinations.append(vac)
                        await app.updatePet(updated)
                    }
                    showAddVaccinationSheet = false
                } onCancel: { showAddVaccinationSheet = false }
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
                } onCancel: { showAddTreatmentSheet = false }
            }
        }
        .alert("Удалить \(pet?.name ?? "")?", isPresented: $showDeleteAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                Task { await app.deletePet(id: petId); dismiss() }
            }
        } message: { Text("Все данные питомца будут удалены. Это действие нельзя отменить.") }
        .alert("Нет интернета", isPresented: $showOfflineAlert) {
            Button("ОК", role: .cancel) { }
        } message: { Text(offlineAlertMessage) }
    }

    // MARK: - Hero

    @ViewBuilder
    private func heroSection(pet: Pet) -> some View {
        if let urlString = pet.photo {
            photoHero(urlString: urlString, pet: pet)
        } else {
            gradientHero(pet: pet)
        }
    }

    @ViewBuilder
    private func photoHero(urlString: String, pet: Pet) -> some View {
        let imageView = resolvedImage(urlString: urlString)
        if let imageView {
            ZStack(alignment: .bottomLeading) {
                imageView
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 280)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .center, endPoint: .bottom
                )
                .frame(maxWidth: .infinity, maxHeight: 160)

                VStack(alignment: .leading, spacing: 6) {
                    speciesBadge(pet: pet)
                    Text(pet.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text(pet.breed)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        } else if urlString.hasPrefix("ava_") {
            gradientHero(pet: pet)
        } else if let u = URL(string: urlString) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: u) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(PetCareTheme.primary.opacity(0.2))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 280)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .center, endPoint: .bottom
                )
                .frame(maxWidth: .infinity, maxHeight: 160)

                VStack(alignment: .leading, spacing: 6) {
                    speciesBadge(pet: pet)
                    Text(pet.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text(pet.breed)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        } else {
            gradientHero(pet: pet)
        }
    }

    private func resolvedImage(urlString: String) -> Image? {
        guard !urlString.hasPrefix("ava_") else { return nil }
        guard urlString.hasPrefix("file://"),
              let path = URL(string: urlString)?.path,
              let uiImage = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: uiImage)
    }

    private func gradientHero(pet: Pet) -> some View {
        ZStack {
            LinearGradient(
                colors: [PetCareTheme.primary, PetCareTheme.primary.opacity(0.75)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(.rect(bottomLeadingRadius: 32, bottomTrailingRadius: 32))

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 88, height: 88)
                    Image(speciesImageName(pet.species))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 52, height: 52)
                }
                VStack(spacing: 4) {
                    Text(pet.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text(pet.breed)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }

    private func speciesBadge(pet: Pet) -> some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().fill(Color.white.opacity(0.25)).frame(width: 18, height: 18)
                Image(speciesImageName(pet.species))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
            }
            Text(pet.species)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }

    // MARK: - Info

    private func infoSection(pet: Pet) -> some View {
        HStack(spacing: 12) {
            infoTile(icon: "calendar", value: pet.age, label: "Возраст", color: Color(hex: "#2196F3"))
            infoTile(icon: "scalemass", value: String(format: "%.1f кг", pet.weight), label: "Вес", color: Color(hex: "#FF9800"))
            infoTile(icon: "syringe", value: "\(pet.vaccinations.count)", label: "Прививки", color: PetCareTheme.primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func infoTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PetCareTheme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(PetCareTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(PetCareTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PetCareTheme.border, lineWidth: 1))
    }

    // MARK: - Features

    private func featuresSection(pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Особенности", icon: "star.fill", color: Color(hex: "#9C27B0"))
            FlowLayout(spacing: 8) {
                ForEach(pet.features, id: \.self) { f in
                    Text(f)
                        .font(.system(size: 12))
                        .foregroundColor(PetCareTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(PetCareTheme.secondary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(PetCareTheme.border, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: - Vaccinations

    private func vaccinationsSection(pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(title: "Прививки", icon: "syringe.fill", color: PetCareTheme.reminderVaccination)
                Spacer()
                Button {
                    guard networkMonitor.isOnline else {
                        offlineAlertMessage = "Добавление прививки недоступно без интернета"
                        showOfflineAlert = true
                        return
                    }
                    showAddVaccinationSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(networkMonitor.isOnline ? PetCareTheme.primary : PetCareTheme.muted)
                }
                .disabled(!networkMonitor.isOnline)
            }

            if pet.vaccinations.isEmpty {
                emptyCard(text: "Прививки не добавлены")
            } else {
                VStack(spacing: 8) {
                    ForEach(pet.vaccinations) { v in
                        vaccinationRow(v: v, pet: pet)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func vaccinationRow(v: Vaccination, pet: Pet) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "syringe")
                .font(.system(size: 14))
                .foregroundColor(PetCareTheme.reminderVaccination)
                .frame(width: 34, height: 34)
                .background(PetCareTheme.reminderVaccination.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(v.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(PetCareTheme.primary)
                HStack(spacing: 8) {
                    Label(v.date, systemImage: "calendar")
                    Text("·")
                    Label("след. \(v.nextDate)", systemImage: "arrow.clockwise")
                }
                .font(.system(size: 11))
                .foregroundColor(PetCareTheme.muted)
            }
            Spacer()

            Text("Активна")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(PetCareTheme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PetCareTheme.primary.opacity(0.1))
                .clipShape(Capsule())

            Button {
                guard networkMonitor.isOnline else {
                    offlineAlertMessage = "Удаление прививки недоступно без интернета"
                    showOfflineAlert = true
                    return
                }
                Task {
                    guard var p = app.pets.first(where: { $0.id == petId }) else { return }
                    p.vaccinations.removeAll { $0.id == v.id }
                    await app.updatePet(p)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(networkMonitor.isOnline ? .red.opacity(0.7) : PetCareTheme.muted)
            }
            .buttonStyle(.plain)
            .disabled(!networkMonitor.isOnline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PetCareTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PetCareTheme.border, lineWidth: 1))
    }

    // MARK: - Treatments

    private func treatmentsSection(pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(title: "Обработки", icon: "ant.fill", color: PetCareTheme.reminderDeworming)
                Spacer()
                Button {
                    guard networkMonitor.isOnline else {
                        offlineAlertMessage = "Добавление обработки недоступно без интернета"
                        showOfflineAlert = true
                        return
                    }
                    showAddTreatmentSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(networkMonitor.isOnline ? PetCareTheme.primary : PetCareTheme.muted)
                }
                .disabled(!networkMonitor.isOnline)
            }

            if pet.treatments.isEmpty {
                emptyCard(text: "Обработки не добавлены")
            } else {
                VStack(spacing: 8) {
                    ForEach(pet.treatments) { t in
                        treatmentRow(t: t, pet: pet)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func treatmentRow(t: Treatment, pet: Pet) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cross.vial")
                .font(.system(size: 14))
                .foregroundColor(PetCareTheme.reminderDeworming)
                .frame(width: 34, height: 34)
                .background(PetCareTheme.reminderDeworming.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(t.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(PetCareTheme.primary)
                Label(t.date, systemImage: "calendar")
                    .font(.system(size: 11))
                    .foregroundColor(PetCareTheme.muted)
            }
            Spacer()

            Button {
                guard networkMonitor.isOnline else {
                    offlineAlertMessage = "Удаление обработки недоступно без интернета"
                    showOfflineAlert = true
                    return
                }
                Task {
                    guard var p = app.pets.first(where: { $0.id == petId }) else { return }
                    p.treatments.removeAll { $0.id == t.id }
                    await app.updatePet(p)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(networkMonitor.isOnline ? .red.opacity(0.7) : PetCareTheme.muted)
            }
            .buttonStyle(.plain)
            .disabled(!networkMonitor.isOnline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PetCareTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(PetCareTheme.border, lineWidth: 1))
    }

    // MARK: - Health link

    private var healthLinkButton: some View {
        Button {
            app.selectedTab = .health
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                Text("Мониторинг здоровья")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(PetCareTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(PetCareTheme.primary)
        }
    }

    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(PetCareTheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(PetCareTheme.border, lineWidth: 1))
    }

}

// MARK: - Flow layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, p) in arrange(proposal: proposal, subviews: subviews).positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Edit pet sheet

struct EditPetSheet: View {
    let pet: Pet
    let onSave: (Pet) -> Void
    let onCancel: () -> Void

    private let speciesOptions: [String] = [
        "Собака", "Кошка", "Попугай", "Кролик",
        "Рыбка", "Хомяк", "Змея", "Черепаха",
        "Ящерица", "Ёж", "Сурикат", "Другое"
    ]

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    @State private var name: String
    @State private var species: String
    @State private var customSpecies: String
    @State private var breed: String
    @State private var birthDate: Date
    @State private var weight: String
    @State private var featuresText: String
    @State private var photoPath: String?
    @FocusState private var focusedField: Field?

    private enum Field { case name, breed, weight, features, customSpecies }

    init(pet: Pet, onSave: @escaping (Pet) -> Void, onCancel: @escaping () -> Void) {
        self.pet = pet
        self.onSave = onSave
        self.onCancel = onCancel
        let knownSpecies = ["Собака", "Кошка", "Попугай", "Птица", "Кролик", "Рыбка", "Хомяк", "Змея", "Черепаха", "Ящерица", "Ёж", "Сурикат"]
        if knownSpecies.contains(pet.species) {
            _species = State(initialValue: pet.species)
            _customSpecies = State(initialValue: "")
        } else {
            _species = State(initialValue: "Другое")
            _customSpecies = State(initialValue: pet.species)
        }
        _name = State(initialValue: pet.name)
        _breed = State(initialValue: pet.breed == "Не указана" ? "" : pet.breed)
        _birthDate = State(initialValue: Self.isoFormatter.date(from: pet.birthDate) ?? Date())
        _weight = State(initialValue: pet.weight > 0 ? String(format: "%.1f", pet.weight) : "")
        _featuresText = State(initialValue: pet.features.joined(separator: ", "))
        _photoPath = State(initialValue: pet.photo)
    }

    private var selectedImageName: String { speciesImageName(species) }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 16)

            HStack {
                Text("Редактировать")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
                Spacer()
                Button(action: save) {
                    Text("Сохранить")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? PetCareTheme.muted : PetCareTheme.primary)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Avatar
                    VStack(spacing: 8) {
                        AvatarPickerButton(photoPath: $photoPath, imageName: selectedImageName, size: 80)
                        Text("Нажмите, чтобы изменить фото")
                            .font(.system(size: 12))
                            .foregroundColor(PetCareTheme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)

                    // Name
                    fieldCard(icon: "pencil", iconColor: PetCareTheme.primary, label: "Имя *") {
                        TextField("Введите имя питомца", text: $name)
                            .focused($focusedField, equals: .name)
                            .font(.system(size: 14))
                    }

                    // Species
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Вид")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(speciesOptions, id: \.self) { option in
                                let selected = species == option
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { species = option }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(speciesImageName(option))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 28, height: 28)
                                        Text(option)
                                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                            .foregroundColor(selected ? PetCareTheme.primary : PetCareTheme.muted)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(PetCareTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                                        selected ? PetCareTheme.primary : PetCareTheme.border,
                                        lineWidth: selected ? 1.5 : 1
                                    ))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if species == "Другое" {
                        fieldCard(icon: "pawprint", iconColor: .purple, label: "Укажите вид") {
                            TextField("Укажите вид", text: $customSpecies)
                                .focused($focusedField, equals: .customSpecies)
                                .font(.system(size: 14))
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    fieldCard(icon: "list.bullet", iconColor: Color(hex: "#4CAF50"), label: "Порода") {
                        TextField("Порода (необязательно)", text: $breed)
                            .focused($focusedField, equals: .breed)
                            .font(.system(size: 14))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("Дата рождения")
                        HStack(spacing: 10) {
                            Image(systemName: "gift")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#E91E63"))
                                .frame(width: 28, height: 28)
                                .background(Color(hex: "#E91E63").opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PetCareTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border, lineWidth: 1))
                    }

                    fieldCard(icon: "scalemass", iconColor: Color(hex: "#FF9800"), label: "Вес (кг)") {
                        TextField("0.0", text: $weight)
                            .focused($focusedField, equals: .weight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 14))
                            .onChange(of: weight) { _, new in
                                let f = new.filter { $0.isNumber || $0 == "." || $0 == "," }
                                if f != new { weight = f }
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        fieldCard(icon: "star", iconColor: Color(hex: "#9C27B0"), label: "Особенности") {
                            TextField("Аллергия, любит играть...", text: $featuresText)
                                .focused($focusedField, equals: .features)
                                .font(.system(size: 14))
                        }
                        Text("Через запятую")
                            .font(.system(size: 11))
                            .foregroundColor(PetCareTheme.muted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(PetCareTheme.background)
        .presentationDetents([.large])
        .presentationCornerRadius(24)
        .presentationDragIndicator(.hidden)
        .ignoresSafeArea(.keyboard)
    }

    private func fieldCard<C: View>(icon: String, iconColor: Color, label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(label)
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                content()
                    .foregroundColor(PetCareTheme.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border, lineWidth: 1))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(PetCareTheme.muted)
    }

    private func save() {
        let birthString = Self.isoFormatter.string(from: birthDate)
        let trimmedCustom = customSpecies.trimmingCharacters(in: .whitespaces)
        let finalSpecies = species == "Другое" ? (trimmedCustom.isEmpty ? "Другое" : trimmedCustom) : species
        let normalizedWeight = weight.replacingOccurrences(of: ",", with: ".")
        var p = pet
        p.name = name.trimmingCharacters(in: .whitespaces)
        p.species = finalSpecies
        p.breed = breed.isEmpty ? "Не указана" : breed
        p.birthDate = birthString
        p.age = PetAgeCalculator.computedAge(from: birthString)
        p.weight = max(0, Double(normalizedWeight) ?? 0)
        p.photo = photoPath
        p.features = featuresText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        onSave(p)
    }
}

// MARK: - Add vaccination sheet

struct AddVaccinationSheet: View {
    let onSave: (Vaccination) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var date = Date()
    @State private var nextDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @FocusState private var nameFocused: Bool

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 16)

            HStack {
                Text("Новая прививка")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
                Spacer()
                Button {
                    let v = Vaccination(
                        id: UUID().uuidString,
                        name: name.trimmingCharacters(in: .whitespaces),
                        date: Self.isoFormatter.string(from: date),
                        nextDate: Self.isoFormatter.string(from: nextDate)
                    )
                    onSave(v)
                } label: {
                    Text("Добавить")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? PetCareTheme.muted : PetCareTheme.primary)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    pickerLabel("Название")
                    HStack(spacing: 10) {
                        Image(systemName: "syringe")
                            .font(.system(size: 13))
                            .foregroundColor(PetCareTheme.reminderVaccination)
                            .frame(width: 28, height: 28)
                            .background(PetCareTheme.reminderVaccination.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        TextField("Напр.: Бешенство, DHPP", text: $name)
                            .focused($nameFocused)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(PetCareTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border, lineWidth: 1))
                }

                datePicker(label: "Дата прививки", icon: "calendar", color: Color(hex: "#2196F3"), selection: $date)
                datePicker(label: "Следующая прививка", icon: "arrow.clockwise", color: Color(hex: "#4CAF50"), selection: $nextDate)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(PetCareTheme.background)
        .presentationDetents([.height(380)])
        .presentationCornerRadius(24)
        .presentationDragIndicator(.hidden)
        .onAppear { nameFocused = true }
    }

    private func pickerLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .medium)).foregroundColor(PetCareTheme.muted)
    }

    private func datePicker(label: String, icon: String, color: Color, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            pickerLabel(label)
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                DatePicker("", selection: selection, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border, lineWidth: 1))
        }
    }
}

// MARK: - Add treatment sheet

struct AddTreatmentSheet: View {
    let onSave: (Treatment) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var date = Date()
    @FocusState private var nameFocused: Bool

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 16)

            HStack {
                Text("Новая обработка")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
                Spacer()
                Button {
                    onSave(Treatment(
                        id: UUID().uuidString,
                        name: name.trimmingCharacters(in: .whitespaces),
                        date: Self.isoFormatter.string(from: date)
                    ))
                } label: {
                    Text("Добавить")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? PetCareTheme.muted : PetCareTheme.primary)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    label("Название")
                    HStack(spacing: 10) {
                        Image(systemName: "cross.vial")
                            .font(.system(size: 13))
                            .foregroundColor(PetCareTheme.reminderDeworming)
                            .frame(width: 28, height: 28)
                            .background(PetCareTheme.reminderDeworming.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        TextField("Напр.: Антипаразитарная обработка", text: $name)
                            .focused($nameFocused)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(PetCareTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 8) {
                    label("Дата")
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#2196F3"))
                            .frame(width: 28, height: 28)
                            .background(Color(hex: "#2196F3").opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PetCareTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border, lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(PetCareTheme.background)
        .presentationDetents([.height(310)])
        .presentationCornerRadius(24)
        .presentationDragIndicator(.hidden)
        .onAppear { nameFocused = true }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .medium)).foregroundColor(PetCareTheme.muted)
    }
}
