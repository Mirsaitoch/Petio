//
//  AddDiarySheet.swift
//  Petio
//

import SwiftUI

struct AddDiarySheet: View {
    let petId: String
    let onSave: (HealthDiaryEntry) -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var app: AppState

    @State private var note = ""
    @State private var date = Date()
    @State private var selectedTagIds: Set<String> = []
    @State private var showNewTagForm = false
    @State private var newTagName = ""
    @State private var newTagColor = Color(hex: "#2196F3")

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Дата") {
                    DatePicker("Дата", selection: $date, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                Section("Заметка") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }

                Section("Теги") {
                    tagGrid
                    newTagToggle
                }
            }
            .navigationTitle("Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let selectedTags = app.allDiaryTags.filter { selectedTagIds.contains($0.id) }
                        let e = HealthDiaryEntry(
                            id: UUID().uuidString,
                            petId: petId,
                            date: AddDiarySheet.isoFormatter.string(from: date),
                            note: note,
                            tags: selectedTags
                        )
                        onSave(e)
                    }
                    .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Tag grid

    private var tagGrid: some View {
        FlowLayoutSimple(spacing: 8) {
            ForEach(app.allDiaryTags) { tag in
                let isSelected = selectedTagIds.contains(tag.id)
                Button {
                    if isSelected {
                        selectedTagIds.remove(tag.id)
                    } else {
                        selectedTagIds.insert(tag.id)
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text(tag.name)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundColor(isSelected ? .white : Color(hex: tag.colorHex))
                    .background(
                        isSelected
                            ? Color(hex: tag.colorHex)
                            : Color(hex: tag.colorHex).opacity(0.12)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: tag.colorHex), lineWidth: isSelected ? 0 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - New tag form

    private var newTagToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { showNewTagForm.toggle() }
            } label: {
                Label(showNewTagForm ? "Скрыть" : "+ Свой тег", systemImage: showNewTagForm ? "chevron.up" : "tag")
                    .font(.system(size: 13))
                    .foregroundColor(PetCareTheme.primary)
            }
            .buttonStyle(.plain)

            if showNewTagForm {
                VStack(spacing: 8) {
                    TextField("Название тега", text: $newTagName)
                        .font(.system(size: 14))
                    HStack {
                        Text("Цвет")
                            .font(.system(size: 14))
                            .foregroundColor(PetCareTheme.muted)
                        Spacer()
                        ColorPicker("", selection: $newTagColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                    Button("Создать тег") {
                        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let tag = DiaryTag(
                            id: UUID().uuidString,
                            name: trimmed,
                            colorHex: newTagColor.hexString,
                            isDefault: false
                        )
                        app.addCustomTag(tag)
                        selectedTagIds.insert(tag.id)
                        newTagName = ""
                        newTagColor = Color(hex: "#2196F3")
                        withAnimation { showNewTagForm = false }
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(PetCareTheme.primary)
                    .frame(maxWidth: .infinity)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Simple flow layout for tags

/// Lightweight flow layout used only for tag chips inside forms.
struct FlowLayoutSimple: Layout {
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
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
