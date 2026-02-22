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
            .background(PetCareTheme.background)
        }
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
        .background {
            VStack {
                PetCareTheme.primary
                PetCareTheme.background
            }
            .ignoresSafeArea()
        }
    }
    
    private var header: some View {
        ZStack {
            PetCareTheme.primary.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                Text("Здоровье")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
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
                            .rotationEffect(.degrees(showPetPicker ? 180 : 0))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                if showPetPicker {
                    VStack(spacing: 4) {
                        ForEach(Array(app.pets.enumerated()), id: \.element.id) { index, p in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    app.selectedPetId = p.id
                                    showPetPicker = false
                                }
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
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.92)).combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.92))
                            ))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showPetPicker)
        }
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32,
                topTrailingRadius: 0
            )
        )
        .padding(.bottom, 16)
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
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progressPercent)
            .padding(.horizontal, 20)
            
            ChipGroup(
                labels: ["Все", "Кормление", "Прививки", "Обработка", "Груминг"],
                selection: $filterType
            )
            .padding(.horizontal, 20)
            
            ForEach(Array(petReminders.enumerated()), id: \.element.id) { index, r in
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
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.96)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(min(index, 8)) * 0.03), value: petReminders.map(\.id))
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
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeOut(duration: 0.3), value: selectedTab)
            
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
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeOut(duration: 0.35).delay(0.05), value: petWeightData.count)
            }
            
            PetCareDashedButton(title: "Добавить запись веса") {
                showAddWeight = true
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var diaryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(petDiary.enumerated()), id: \.element.id) { index, entry in
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
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97)),
                    removal: .opacity.combined(with: .scale(scale: 0.97))
                ))
                .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(min(index, 6)) * 0.05), value: petDiary.map(\.id))
            }
            PetCareDashedButton(title: "Новая запись") {
                showAddDiary = true
            }
            .padding(.horizontal, 20)
        }
    }
}
