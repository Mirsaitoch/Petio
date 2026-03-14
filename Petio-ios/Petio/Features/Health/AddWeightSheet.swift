//
//  AddWeightSheet.swift
//  Petio
//

import SwiftUI

struct AddWeightSheet: View {
    let petId: String
    let onSave: (WeightRecord) -> Void
    let onCancel: () -> Void

    @State private var weight = ""
    @State private var date = Date()
    @FocusState private var weightFocused: Bool

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private var canSave: Bool {
        guard let w = Double(weight.replacingOccurrences(of: ",", with: ".")) else { return false }
        return w > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Header
            HStack {
                Text("Запись веса")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
                Spacer()
                Button {
                    let normalized = weight.replacingOccurrences(of: ",", with: ".")
                    guard let w = Double(normalized) else { return }
                    onSave(WeightRecord(date: Self.isoFormatter.string(from: date), weight: w))
                } label: {
                    Text("Сохранить")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(canSave ? PetCareTheme.primary : PetCareTheme.muted)
                }
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // Weight input card
            VStack(spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    TextField("0.0", text: $weight)
                        .keyboardType(.decimalPad)
                        .focused($weightFocused)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(PetCareTheme.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 160)
                        .onChange(of: weight) { _, new in
                            let filtered = new.filter { $0.isNumber || $0 == "." || $0 == "," }
                            if filtered != new { weight = filtered }
                        }
                    Text("кг")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(PetCareTheme.muted)
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)

                Text("Введите вес")
                    .font(.system(size: 12))
                    .foregroundColor(PetCareTheme.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                weightFocused ? PetCareTheme.primary.opacity(0.4) : PetCareTheme.border,
                lineWidth: weightFocused ? 1.5 : 1
            ))
            .animation(.easeInOut(duration: 0.15), value: weightFocused)
            .padding(.horizontal, 20)
            .onTapGesture { weightFocused = true }

            // Date picker
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#2196F3"))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: "#2196F3").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Дата")
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.primary)
                Spacer()
                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 32)
        .background(PetCareTheme.background)
        .presentationDetents([.height(360), .large])
        .presentationCornerRadius(24)
        .presentationDragIndicator(.hidden)
        .ignoresSafeArea(.keyboard)
        .onAppear { weightFocused = true }
    }
}
