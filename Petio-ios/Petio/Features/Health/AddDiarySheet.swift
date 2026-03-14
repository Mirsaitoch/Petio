//
//  AddDiarySheet.swift
//  Petio
//

import SwiftUI

struct AddDiarySheet: View {
    let existingEntry: HealthDiaryEntry?
    let pets: [Pet]
    let onSave: (HealthDiaryEntry) -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var app: AppState

    @State private var selectedPetId: String
    @State private var note: String
    @State private var date: Date
    @State private var selectedTagIds: Set<String>
    @State private var showNewTagForm = false
    @State private var newTagName = ""
    @State private var newTagColor = Color(hex: "#2196F3")
    @FocusState private var noteFocused: Bool

    static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    init(petId: String, pets: [Pet] = [], existingEntry: HealthDiaryEntry? = nil,
         onSave: @escaping (HealthDiaryEntry) -> Void,
         onCancel: @escaping () -> Void) {
        self.pets = pets
        self.existingEntry = existingEntry
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedPetId = State(initialValue: existingEntry?.petId ?? petId)
        _note = State(initialValue: existingEntry?.note ?? "")
        _selectedTagIds = State(initialValue: Set(existingEntry?.tags.map(\.id) ?? []))
        let parsedDate = existingEntry.flatMap { AddDiarySheet.isoFormatter.date(from: $0.date) } ?? Date()
        _date = State(initialValue: parsedDate)
    }

    private var isEditing: Bool { existingEntry != nil }
    private var canSave: Bool { !note.trimmingCharacters(in: .whitespaces).isEmpty && !selectedPetId.isEmpty }

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
                Text(isEditing ? "Редактировать запись" : "Новая запись")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
                Spacer()
                Button {
                    let selectedTags = app.allDiaryTags.filter { selectedTagIds.contains($0.id) }
                    let e = HealthDiaryEntry(
                        id: existingEntry?.id ?? UUID().uuidString,
                        petId: selectedPetId,
                        date: AddDiarySheet.isoFormatter.string(from: date),
                        note: note,
                        tags: selectedTags
                    )
                    onSave(e)
                } label: {
                    Text("Сохранить")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(canSave ? PetCareTheme.primary : PetCareTheme.muted)
                }
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if pets.count > 1 && !isEditing { petPickerSection }
                    noteSection
                    dateSection
                    tagsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(PetCareTheme.background)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(24)
        .presentationDragIndicator(.hidden)
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Pet picker

    private var petPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Питомец")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pets) { pet in
                        let selected = selectedPetId == pet.id
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                selectedPetId = pet.id
                            }
                        } label: {
                            HStack(spacing: 6) {
                                AvatarView(url: pet.photo, imageName: speciesImageName(pet.species), size: 24)
                                Text(pet.name)
                                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                                    .foregroundColor(selected ? PetCareTheme.primary : PetCareTheme.muted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selected ? PetCareTheme.primary.opacity(0.1) : PetCareTheme.cardBackground)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Заметка")
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("Как дела у питомца?")
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.muted.opacity(0.6))
                        .padding(.top, 12)
                        .padding(.leading, 14)
                }
                TextEditor(text: $note)
                    .focused($noteFocused)
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.primary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                noteFocused ? PetCareTheme.primary.opacity(0.5) : PetCareTheme.border,
                lineWidth: noteFocused ? 1.5 : 1
            ))
            .animation(.easeInOut(duration: 0.15), value: noteFocused)
        }
    }

    // MARK: - Date

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Дата")
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#2196F3"))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: "#2196F3").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
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
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Теги")
            if !app.allDiaryTags.isEmpty {
                tagChips
            }
            newTagToggle
        }
    }

    private var tagChips: some View {
        FlowLayoutSimple(spacing: 8) {
            ForEach(app.allDiaryTags) { tag in
                let isSelected = selectedTagIds.contains(tag.id)
                Button {
                    if isSelected { selectedTagIds.remove(tag.id) }
                    else { selectedTagIds.insert(tag.id) }
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
                    .background(isSelected ? Color(hex: tag.colorHex) : Color(hex: tag.colorHex).opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(hex: tag.colorHex), lineWidth: isSelected ? 0 : 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private var newTagToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showNewTagForm.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showNewTagForm ? "minus.circle" : "plus.circle")
                        .font(.system(size: 14))
                    Text(showNewTagForm ? "Скрыть" : "Свой тег")
                        .font(.system(size: 13))
                }
                .foregroundColor(PetCareTheme.primary)
            }
            .buttonStyle(.plain)

            if showNewTagForm {
                HStack(spacing: 10) {
                    TextField("Название тега", text: $newTagName)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity)
                    ColorPicker("", selection: $newTagColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 28, height: 28)
                    Button {
                        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let tag = DiaryTag(id: UUID().uuidString, name: trimmed,
                                          colorHex: newTagColor.hexString, isDefault: false)
                        app.addCustomTag(tag)
                        selectedTagIds.insert(tag.id)
                        newTagName = ""
                        newTagColor = Color(hex: "#2196F3")
                        withAnimation { showNewTagForm = false }
                    } label: {
                        Text("Создать")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                newTagName.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? PetCareTheme.muted
                                    : PetCareTheme.primary
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PetCareTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.primary.opacity(0.3), lineWidth: 1.5))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(PetCareTheme.muted)
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
