//
//  PetDetailView.swift
//  Petio
//

import SwiftUI
import PhotosUI
import Charts

struct PetDetailView: View {
    let petId: String
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showAddVaccinationSheet = false
    @State private var showAddReminder = false
    @State private var showAddDiary = false
    @State private var showAddWeight = false
    @State private var editingDiaryEntry: HealthDiaryEntry? = nil
    @State private var editingReminder: Reminder? = nil
    @State private var offlineAlertMessage = ""
    @State private var showOfflineAlert = false

    private var pet: Pet? { app.pets.first { $0.id == petId } }

    var body: some View {
        Group {
            if let pet {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        heroSection(pet: pet)
                        if !pet.features.isEmpty { featuresSection(pet: pet) }
                        PetRemindersCompactSection(
                            petId: petId,
                            onAddReminder: { showAddReminder = true }
                        )
                        PetWeightCompactSection(
                            petId: petId,
                            onAddWeight: { showAddWeight = true }
                        )
                        vaccinationsSection(pet: pet)
                        PetDiaryCompactSection(
                            petId: petId,
                            onAddDiary: { showAddDiary = true },
                            onEditEntry: { editingDiaryEntry = $0 }
                        )
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
                Button("Редактировать", systemImage: "pencil") {
                    guard networkMonitor.isOnline else {
                        offlineAlertMessage = "Редактирование недоступно без интернета"
                        showOfflineAlert = true
                        return
                    }
                    showEditSheet = true
                }
                .disabled(!networkMonitor.isOnline)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Удалить", systemImage: "trash", role: .destructive) {
                    guard networkMonitor.isOnline else {
                        offlineAlertMessage = "Удаление недоступно без интернета"
                        showOfflineAlert = true
                        return
                    }
                    showDeleteAlert = true
                }
                .disabled(!networkMonitor.isOnline)
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
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .petReminders(let id):
                PetRemindersView(petId: id)
            case .petWeight(let id):
                PetWeightView(petId: id)
            case .petDiary(let id):
                PetDiaryView(petId: id)
            default:
                EmptyView()
            }
        }
        .sheet(isPresented: $showAddReminder) {
            AddReminderSheet(selectedPetId: petId, pets: app.pets) { r in
                Task { await app.addReminder(r) }
                showAddReminder = false
            } onCancel: { showAddReminder = false }
        }
        .sheet(isPresented: $showAddDiary) {
            AddDiarySheet(petId: petId) { e in
                Task { await app.addDiaryEntry(e) }
                showAddDiary = false
            } onCancel: { showAddDiary = false }
        }
        .sheet(isPresented: $showAddWeight) {
            AddWeightSheet(petId: petId) { r in
                Task { await app.addWeightRecord(petId: petId, r) }
                showAddWeight = false
            } onCancel: { showAddWeight = false }
        }
        .sheet(item: $editingDiaryEntry) { entry in
            AddDiarySheet(petId: entry.petId, existingEntry: entry) { updated in
                Task { await app.updateDiaryEntry(updated) }
                editingDiaryEntry = nil
            } onCancel: { editingDiaryEntry = nil }
        }
        .sheet(item: $editingReminder) { reminder in
            AddReminderSheet(selectedPetId: reminder.petId, pets: app.pets, existingReminder: reminder) { updated in
                Task { await app.updateReminder(updated) }
                editingReminder = nil
            } onCancel: { editingReminder = nil }
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

    private func heroSection(pet: Pet) -> some View {
        VStack(spacing: 16) {
            petAvatar(pet: pet)
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(speciesImageName(pet.species))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    Text(pet.name)
                        .font(.title2)
                        .bold()
                        .foregroundStyle(PetCareTheme.primary)
                }
                Text("\(pet.breed) · \(pet.ageDisplay)")
                    .font(.subheadline)
                    .foregroundStyle(PetCareTheme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func petAvatar(pet: Pet) -> some View {
        if let urlString = pet.photo, let image = resolvedLocalImage(urlString: urlString) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(.circle)
                .overlay(Circle().stroke(PetCareTheme.border, lineWidth: 2))
                .shadow(color: PetCareTheme.primary.opacity(0.15), radius: 12, y: 4)
        } else if let urlString = pet.photo,
                  let url = URL(string: urlString),
                  urlString.hasPrefix("http") {
            AsyncImage(url: url) { phase in
                if let img = phase.image {
                    img.resizable().aspectRatio(contentMode: .fill)
                } else if phase.error != nil {
                    placeholderAvatar(pet: pet)
                } else {
                    ProgressView()
                        .frame(width: 120, height: 120)
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(.circle)
            .overlay(Circle().stroke(PetCareTheme.border, lineWidth: 2))
            .shadow(color: PetCareTheme.primary.opacity(0.15), radius: 12, y: 4)
        } else {
            placeholderAvatar(pet: pet)
        }
    }

    private func placeholderAvatar(pet: Pet) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PetCareTheme.primary.opacity(0.15), PetCareTheme.primary.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(speciesImageName(pet.species))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
        }
        .frame(width: 120, height: 120)
        .overlay(Circle().stroke(PetCareTheme.border, lineWidth: 2))
    }

    private func resolvedLocalImage(urlString: String) -> Image? {
        guard urlString.hasPrefix("file://"),
              let path = URL(string: urlString)?.path,
              let uiImage = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: uiImage)
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
                    if let nextDate = v.nextDate {
                        Text("·")
                        Label("до \(nextDate)", systemImage: "clock")
                    }
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

// MARK: - Compact health sections

struct PetRemindersCompactSection: View {
    let petId: String
    let onAddReminder: () -> Void
    @EnvironmentObject private var app: AppState

    private var allReminders: [Reminder] {
        app.reminders(forPetId: petId, typeFilter: nil)
    }

    private var progressPercent: Int {
        let total = allReminders.count
        guard total > 0 else { return 0 }
        let done = allReminders.filter(\.completed).count
        return Int((Double(done) / Double(total)) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(title: "Напоминания", icon: "bell.fill", color: Color(hex: "#FF9800"))
                Spacer()
                Button(action: onAddReminder) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PetCareTheme.primary)
                }
            }

            if allReminders.isEmpty {
                Text("Напоминания не добавлены")
                    .font(.system(size: 13))
                    .foregroundStyle(PetCareTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(PetCareTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(PetCareTheme.border, lineWidth: 1))
            } else {
                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Прогресс")
                            .font(.system(size: 13))
                            .foregroundStyle(PetCareTheme.primary)
                        Spacer()
                        Text("\(progressPercent)%")
                            .font(.system(size: 13))
                            .foregroundStyle(PetCareTheme.primary)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(PetCareTheme.secondary)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(PetCareTheme.primary)
                                .frame(width: max(0, g.size.width * CGFloat(progressPercent) / 100), height: 8)
                        }
                    }
                    .frame(height: 8)
                    Text("\(allReminders.filter(\.completed).count) из \(allReminders.count) задач")
                        .font(.system(size: 11))
                        .foregroundStyle(PetCareTheme.muted)
                }
                .padding(14)
                .petCareCardStyle()

                // Show up to 3 reminders
                ForEach(allReminders.prefix(3)) { r in
                    PetCareReminderRow(
                        title: r.title,
                        subtitle: "\(r.date) · \(r.time)",
                        icon: r.type.sfSymbol,
                        iconColor: r.type.color,
                        completed: r.completed,
                        onToggle: { app.toggleReminder(id: r.id) }
                    )
                }

                // "Show all" link
                NavigationLink(value: AppRoute.petReminders(petId)) {
                    HStack {
                        Text("Все напоминания")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(allReminders.count)")
                            .font(.system(size: 13))
                            .foregroundStyle(PetCareTheme.muted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PetCareTheme.muted)
                    }
                    .foregroundStyle(PetCareTheme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(PetCareTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(PetCareTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PetCareTheme.primary)
        }
    }
}

struct PetWeightCompactSection: View {
    let petId: String
    let onAddWeight: () -> Void
    @EnvironmentObject private var app: AppState

    private var pet: Pet? { app.pets.first { $0.id == petId } }
    private var weightData: [WeightRecord] { app.weightRecords(forPetId: petId) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(title: "Вес", icon: "scalemass.fill", color: Color(hex: "#2196F3"))
                Spacer()
                Button(action: onAddWeight) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PetCareTheme.primary)
                }
            }

            // Current weight card
            HStack {
                Text("Текущий вес")
                    .font(.system(size: 13))
                    .foregroundStyle(PetCareTheme.muted)
                Spacer()
                Text(pet?.weight ?? 0, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PetCareTheme.primary)
                + Text(" кг")
                    .font(.system(size: 14))
                    .foregroundStyle(PetCareTheme.muted)
            }
            .padding(14)
            .petCareCardStyle()

            // Mini chart
            if !weightData.isEmpty {
                Chart(weightData, id: \.date) { rec in
                    LineMark(
                        x: .value("Месяц", rec.date),
                        y: .value("Вес", rec.weight)
                    )
                    .foregroundStyle(PetCareTheme.primary)
                    PointMark(
                        x: .value("Месяц", rec.date),
                        y: .value("Вес", rec.weight)
                    )
                    .foregroundStyle(PetCareTheme.primary)
                }
                .frame(height: 120)
                .padding(14)
                .petCareCardStyle()
            }

            // "Show all" link
            NavigationLink(value: AppRoute.petWeight(petId)) {
                HStack {
                    Text("Вся история")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PetCareTheme.muted)
                }
                .foregroundStyle(PetCareTheme.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(PetCareTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(PetCareTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PetCareTheme.primary)
        }
    }
}

struct PetDiaryCompactSection: View {
    let petId: String
    let onAddDiary: () -> Void
    let onEditEntry: (HealthDiaryEntry) -> Void
    @EnvironmentObject private var app: AppState

    private var petDiary: [HealthDiaryEntry] {
        app.diary(forPetId: petId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(title: "Дневник здоровья", icon: "book.fill", color: Color(hex: "#9C27B0"))
                Spacer()
                Button(action: onAddDiary) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(PetCareTheme.primary)
                }
            }

            if petDiary.isEmpty {
                Text("Записей пока нет")
                    .font(.system(size: 13))
                    .foregroundStyle(PetCareTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(PetCareTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(PetCareTheme.border, lineWidth: 1))
            } else {
                // Show last 2 entries
                ForEach(petDiary.prefix(2)) { entry in
                    compactDiaryCard(entry: entry)
                }

                // "Show all" link
                NavigationLink(value: AppRoute.petDiary(petId)) {
                    HStack {
                        Text("Весь дневник")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(petDiary.count)")
                            .font(.system(size: 13))
                            .foregroundStyle(PetCareTheme.muted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PetCareTheme.muted)
                    }
                    .foregroundStyle(PetCareTheme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(PetCareTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(PetCareTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func compactDiaryCard(entry: HealthDiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.date)
                    .font(.system(size: 11))
                    .foregroundStyle(PetCareTheme.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PetCareTheme.secondary)
                    .clipShape(Capsule())
                Spacer()
                Button { onEditEntry(entry) } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(PetCareTheme.muted)
                }
                .buttonStyle(.plain)
            }
            Text(entry.note)
                .font(.system(size: 14))
                .foregroundStyle(PetCareTheme.primary)
                .lineLimit(2)
            if !entry.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(entry.tags.prefix(3)) { tag in
                        Text(tag.name)
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: tag.colorHex))
                            .clipShape(Capsule())
                    }
                    if entry.tags.count > 3 {
                        Text("+\(entry.tags.count - 3)")
                            .font(.system(size: 10))
                            .foregroundStyle(PetCareTheme.muted)
                    }
                }
            }
        }
        .padding(14)
        .petCareCardStyle()
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PetCareTheme.primary)
        }
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
        _birthDate = State(initialValue: DateHelper.parse(pet.birthDate) ?? Self.isoFormatter.date(from: pet.birthDate) ?? Date())
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PetCareTheme.background)
        .presentationDetents([.large])
        .presentationCornerRadius(24)
        .presentationDragIndicator(.hidden)
        .presentationBackground(PetCareTheme.background)
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
        let cal = Calendar.current
        if let bd = Self.isoFormatter.date(from: birthString) {
            p.age = cal.dateComponents([.year], from: bd, to: Date()).year ?? 0
        }
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
    @State private var hasNextDate = false
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
                        nextDate: hasNextDate ? Self.isoFormatter.string(from: nextDate) : nil
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

                Toggle(isOn: $hasNextDate.animation()) {
                    Label("Следующая прививка", systemImage: "clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PetCareTheme.primary)
                }
                .tint(PetCareTheme.primary)

                if hasNextDate {
                    datePicker(label: "Следующая дата", icon: "clock", color: Color(hex: "#4CAF50"), selection: $nextDate)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PetCareTheme.background)
        .presentationDetents([.medium])
        .presentationCornerRadius(24)
        .presentationDragIndicator(.hidden)
        .presentationBackground(PetCareTheme.background)
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

