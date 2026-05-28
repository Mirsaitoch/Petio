//
//  PetDiaryView.swift
//  Petio
//
//  Полноэкранный дневник здоровья для конкретного питомца.
//

import SwiftUI

struct PetDiaryView: View {
    let petId: String
    @EnvironmentObject private var app: AppState
    @State private var showAddDiary = false
    @State private var editingEntry: HealthDiaryEntry? = nil

    private var petDiary: [HealthDiaryEntry] {
        app.diary(forPetId: petId)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(petDiary.enumerated().map { $0 }, id: \.element.id) { index, entry in
                    DiaryEntryCard(entry: entry) {
                        editingEntry = entry
                    } onDelete: {
                        Task { await app.deleteDiaryEntry(id: entry.id) }
                    }
                    .padding(.horizontal, 20)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97)),
                        removal: .opacity.combined(with: .scale(scale: 0.97))
                    ))
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.8).delay(Double(min(index, 6)) * 0.05),
                        value: petDiary.map(\.id)
                    )
                }

                PetCareDashedButton(title: "Новая запись") {
                    showAddDiary = true
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(PetCareTheme.background)
        .navigationTitle("Дневник здоровья")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddDiary) {
            AddDiarySheet(petId: petId) { e in
                Task { await app.addDiaryEntry(e) }
                showAddDiary = false
            } onCancel: { showAddDiary = false }
        }
        .sheet(item: $editingEntry) { entry in
            AddDiarySheet(petId: entry.petId, existingEntry: entry) { updated in
                Task { await app.updateDiaryEntry(updated) }
                editingEntry = nil
            } onCancel: { editingEntry = nil }
        }
    }
}
