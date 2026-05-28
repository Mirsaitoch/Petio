//
//  PetWeightView.swift
//  Petio
//
//  Полноэкранная история веса для конкретного питомца.
//

import SwiftUI
import Charts

struct PetWeightView: View {
    let petId: String
    @EnvironmentObject private var app: AppState
    @State private var showAddWeight = false

    private var pet: Pet? { app.pets.first { $0.id == petId } }
    private var weightData: [WeightRecord] { app.weightRecords(forPetId: petId) }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                currentWeightCard
                if !weightData.isEmpty {
                    chartCard
                }
                PetCareDashedButton(title: "Добавить запись веса") {
                    showAddWeight = true
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(PetCareTheme.background)
        .navigationTitle("Вес")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddWeight) {
            AddWeightSheet(petId: petId) { r in
                Task { await app.addWeightRecord(petId: petId, r) }
                showAddWeight = false
            } onCancel: { showAddWeight = false }
        }
    }

    // MARK: - Current weight

    private var currentWeightCard: some View {
        HStack {
            Text("Текущий вес")
                .font(.system(size: 14))
                .foregroundStyle(PetCareTheme.primary)
            Spacer()
            Text(pet?.weight ?? 0, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(PetCareTheme.primary)
            + Text(" кг")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(PetCareTheme.primary)
        }
        .padding(16)
        .petCareCardStyle()
        .padding(.horizontal, 20)
    }

    // MARK: - Chart

    private var chartCard: some View {
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
        .frame(height: 180)
        .padding(16)
        .petCareCardStyle()
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeOut(duration: 0.35).delay(0.05), value: weightData.count)
    }
}
