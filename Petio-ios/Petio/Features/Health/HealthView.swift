//
//  HealthView.swift
//  Petio
//
//  Здоровье: выбор питомца, табы (Задачи / Вес / Дневник), список напоминаний, график веса, записи дневника.
//

import SwiftUI
import Charts

enum HealthTab: String, CaseIterable {
    case reminders = "Задачи"
    case weight = "Вес"
    case diary = "Дневник"
}

struct HealthView: View {
    @EnvironmentObject private var app: AppState
    @State private var selectedTab: HealthTab = .reminders
    @State private var showPetPicker = false
    @State private var filterType: String = "Все"
    @State private var showAddReminder = false
    @State private var showAddDiary = false
    @State private var showAddWeight = false

    private var selectedPet: Pet? { app.selectedPet }
    private static let filterToRaw: [String: String] = [
        "Все": "all", "Кормление": "feeding", "Прививки": "vaccination",
        "Обработка": "deworming", "Груминг": "grooming"
    ]
    private var petReminders: [Reminder] {
        guard let id = app.selectedPetId.isEmpty ? app.pets.first?.id : app.selectedPetId else { return [] }
        let raw = Self.filterToRaw[filterType] ?? "all"
        return app.reminders(forPetId: id, typeFilter: raw == "all" ? nil : raw)
    }
    private var petDiary: [HealthDiaryEntry] {
        app.diary(forPetId: app.selectedPetId.isEmpty ? (app.pets.first?.id ?? "") : app.selectedPetId)
    }
    private var petWeightData: [WeightRecord] {
        app.weightRecords(forPetId: app.selectedPetId.isEmpty ? (app.pets.first?.id ?? "") : app.selectedPetId)
    }
    private var progressPercent: Int {
        let total = petReminders.count
        guard total > 0 else { return 0 }
        let done = petReminders.filter(\.completed).count
        return Int((Double(done) / Double(total)) * 100)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                tabs
                tabContent
            }
            .padding(.bottom, 24)
        }
        .background(PetCareTheme.background)
        .sheet(isPresented: $showAddReminder) {
            AddReminderSheet(selectedPetId: app.selectedPetId, pets: app.pets) { r in
                Task { await app.addReminder(r) }
                showAddReminder = false
            } onCancel: { showAddReminder = false }
        }
        .sheet(isPresented: $showAddDiary) {
            AddDiarySheet(petId: app.selectedPetId) { e in
                Task { await app.addDiaryEntry(e) }
                showAddDiary = false
            } onCancel: { showAddDiary = false }
        }
        .sheet(isPresented: $showAddWeight) {
            AddWeightSheet(petId: app.selectedPetId) { r in
                Task { await app.addWeightRecord(petId: app.selectedPetId, r) }
                showAddWeight = false
            } onCancel: { showAddWeight = false }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetCareGradientHeader(title: "Здоровье")
            Button {
                showPetPicker.toggle()
            } label: {
                HStack(spacing: 8) {
                    AvatarView(
                        url: selectedPet?.photo,
                        placeholder: "🐾",
                        size: 28
                    )
                    Text(selectedPet?.name ?? "Выберите питомца")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, -8)

            if showPetPicker {
                VStack(spacing: 4) {
                    ForEach(app.pets) { p in
                        Button {
                            app.selectedPetId = p.id
                            showPetPicker = false
                        } label: {
                            HStack(spacing: 8) {
                                AvatarView(url: p.photo, placeholder: "🐾", size: 24)
                                Text(p.name)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(app.selectedPetId == p.id ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(HealthTab.allCases, id: \.rawValue) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14))
                        .foregroundColor(selectedTab == tab ? PetCareTheme.primary : PetCareTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedTab == tab ? Color.white : Color.clear)
                )
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(PetCareTheme.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .reminders:
            remindersContent
        case .weight:
            weightContent
        case .diary:
            diaryContent
        }
    }

    private var remindersContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Прогресс")
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.primary)
                    Spacer()
                    Text("\(progressPercent)%")
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.primary)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(PetCareTheme.secondary)
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(PetCareTheme.primary)
                            .frame(width: g.size.width * CGFloat(progressPercent) / 100, height: 10)
                    }
                }
                .frame(height: 10)
                Text("\(petReminders.filter(\.completed).count) из \(petReminders.count) задач выполнено")
                    .font(.system(size: 11))
                    .foregroundColor(PetCareTheme.muted)
            }
            .padding(16)
            .petCareCardStyle()
            .padding(.horizontal, 20)

            ChipGroup(
                labels: ["Все", "Кормление", "Прививки", "Обработка", "Груминг"],
                selection: $filterType
            )
            .padding(.horizontal, 20)

            ForEach(petReminders) { r in
                PetCareReminderRow(
                    title: r.title,
                    subtitle: "\(r.date) · \(r.time)",
                    icon: r.type.sfSymbol,
                    iconColor: r.type.color,
                    completed: r.completed,
                    onToggle: { app.toggleReminder(id: r.id) },
                    onDelete: { Task { await app.deleteReminder(id: r.id) } }
                )
                .padding(.horizontal, 20)
            }

            PetCareDashedButton(title: "Добавить напоминание", icon: "plus") {
                showAddReminder = true
            }
            .padding(.horizontal, 20)
        }
    }

    private var weightContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Текущий вес")
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.primary)
                Spacer()
                Text("\(selectedPet?.weight ?? 0, specifier: "%.1f") кг")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
            }
            .padding(16)
            .petCareCardStyle()
            .padding(.horizontal, 20)

            if !petWeightData.isEmpty {
                Chart(petWeightData, id: \.date) { rec in
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
                .frame(height: 180)
                .padding(16)
                .petCareCardStyle()
                .padding(.horizontal, 20)
            }

            PetCareDashedButton(title: "Добавить запись веса") {
                showAddWeight = true
            }
            .padding(.horizontal, 20)
        }
    }

    private var diaryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(petDiary) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.date)
                        .font(.system(size: 11))
                        .foregroundColor(PetCareTheme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PetCareTheme.secondary)
                        .clipShape(Capsule())
                    Text(entry.note)
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .petCareCardStyle()
                .padding(.horizontal, 20)
            }
            PetCareDashedButton(title: "Новая запись") {
                showAddDiary = true
            }
            .padding(.horizontal, 20)
        }
    }
}

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

struct AddDiarySheet: View {
    let petId: String
    let onSave: (HealthDiaryEntry) -> Void
    let onCancel: () -> Void

    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Заметка") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let e = HealthDiaryEntry(
                            id: UUID().uuidString,
                            petId: petId,
                            date: "2026-02-17",
                            note: note
                        )
                        onSave(e)
                    }
                    .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

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
