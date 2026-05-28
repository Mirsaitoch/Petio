//
//  PetRemindersView.swift
//  Petio
//
//  Полноэкранный список напоминаний для конкретного питомца.
//

import SwiftUI

struct PetRemindersView: View {
    let petId: String
    @EnvironmentObject private var app: AppState
    @State private var filterType: String = "Все"
    @State private var showAddReminder = false
    @State private var editingReminder: Reminder? = nil

    private static let filterToRaw: [String: String] = [
        "Все": "all", "Кормление": "feeding", "Прививки": "vaccination",
        "Обработка": "deworming", "Груминг": "grooming"
    ]

    private var petReminders: [Reminder] {
        let raw = Self.filterToRaw[filterType] ?? "all"
        return app.reminders(forPetId: petId, typeFilter: raw == "all" ? nil : raw)
    }

    private var progressPercent: Int {
        let total = petReminders.count
        guard total > 0 else { return 0 }
        let done = petReminders.filter(\.completed).count
        return Int((Double(done) / Double(total)) * 100)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                if !petReminders.isEmpty {
                    progressSection
                }

                ChipGroup(
                    haveAdditionalPadding: true,
                    labels: ["Все", "Кормление", "Прививки", "Обработка", "Груминг"],
                    selection: $filterType
                )

                ForEach(petReminders.enumerated().map { $0 }, id: \.element.id) { index, r in
                    SwipeReminderCard(reminder: r) {
                        app.toggleReminder(id: r.id)
                    } onEdit: {
                        editingReminder = r
                    } onDelete: {
                        Task { await app.deleteReminder(id: r.id) }
                    }
                    .padding(.horizontal, 20)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.8).delay(Double(min(index, 8)) * 0.03),
                        value: petReminders.map(\.id)
                    )
                }

                PetCareDashedButton(title: "Добавить напоминание", icon: "plus") {
                    showAddReminder = true
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(PetCareTheme.background)
        .navigationTitle("Напоминания")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddReminder) {
            AddReminderSheet(selectedPetId: petId, pets: app.pets) { r in
                Task { await app.addReminder(r) }
                showAddReminder = false
            } onCancel: { showAddReminder = false }
        }
        .sheet(item: $editingReminder) { reminder in
            AddReminderSheet(selectedPetId: reminder.petId, pets: app.pets, existingReminder: reminder) { updated in
                Task { await app.updateReminder(updated) }
                editingReminder = nil
            } onCancel: { editingReminder = nil }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Прогресс")
                    .font(.system(size: 14))
                    .foregroundStyle(PetCareTheme.primary)
                Spacer()
                Text("\(progressPercent)%")
                    .font(.system(size: 14))
                    .foregroundStyle(PetCareTheme.primary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PetCareTheme.secondary)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PetCareTheme.primary)
                        .frame(width: max(0, g.size.width * CGFloat(progressPercent) / 100), height: 10)
                }
            }
            .frame(height: 10)
            Text("\(petReminders.filter(\.completed).count) из \(petReminders.count) задач выполнено")
                .font(.system(size: 11))
                .foregroundStyle(PetCareTheme.muted)
        }
        .padding(16)
        .petCareCardStyle()
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progressPercent)
        .padding(.horizontal, 20)
    }
}
