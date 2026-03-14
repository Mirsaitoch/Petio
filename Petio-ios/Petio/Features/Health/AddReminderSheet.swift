//
//  AddReminderSheet.swift
//  Petio
//

import SwiftUI

struct AddReminderSheet: View {
    let selectedPetId: String
    let pets: [Pet]
    let existingReminder: Reminder?
    let onSave: (Reminder) -> Void
    let onCancel: () -> Void

    @State private var type: ReminderType
    @State private var customTypeName: String
    @State private var title: String
    @State private var selectedDate: Date
    @State private var selectedTime: Date
    @State private var currentPetId: String
    @FocusState private var customTypeFieldFocused: Bool

    private var isEditing: Bool { existingReminder != nil }

    init(selectedPetId: String, pets: [Pet], existingReminder: Reminder? = nil,
         onSave: @escaping (Reminder) -> Void, onCancel: @escaping () -> Void) {
        self.selectedPetId = selectedPetId
        self.pets = pets
        self.existingReminder = existingReminder
        self.onSave = onSave
        self.onCancel = onCancel
        _type = State(initialValue: existingReminder?.type ?? .feeding)
        _customTypeName = State(initialValue: existingReminder?.customTypeName ?? "")
        _title = State(initialValue: existingReminder?.title ?? "")
        _currentPetId = State(initialValue: existingReminder?.petId ?? (selectedPetId.isEmpty ? (pets.first?.id ?? "") : selectedPetId))

        let dateStr = existingReminder?.date
        let timeStr = existingReminder?.time
        let parsedDate = dateStr.flatMap { Self.dateFormatter.date(from: $0) } ?? Date()
        _selectedDate = State(initialValue: parsedDate)

        if let timeStr, let parsedTime = Self.timeFormatter.date(from: timeStr) {
            _selectedTime = State(initialValue: parsedTime)
        } else {
            var comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
            comps.minute = ((comps.minute ?? 0) / 5 + 1) * 5
            _selectedTime = State(initialValue: Calendar.current.date(from: comps) ?? Date())
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private var canSave: Bool {
        !currentPetId.isEmpty && (type != .other || !customTypeName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // Built-in types (excluding .other which is handled separately)
    private let builtInTypes: [ReminderType] = [.feeding, .vaccination, .deworming, .grooming]

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Header
            HStack {
                Text(isEditing ? "Редактировать" : "Новое напоминание")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
                Spacer()
                Button(action: save) {
                    Text(isEditing ? "Сохранить" : "Добавить")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(canSave ? PetCareTheme.primary : PetCareTheme.muted)
                }
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    typeSection
                    if type == .other { customTypeField }
                    nameField
                    dateTimeRow
                    if pets.count > 1 { petRow }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(PetCareTheme.background)
        .presentationDetents([.height(500), .large])
        .presentationCornerRadius(24)
        .presentationDragIndicator(.hidden)
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Type section

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Тип")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(builtInTypes, id: \.self) { t in typeCard(t) }
                otherCard
            }
        }
    }

    private func typeCard(_ t: ReminderType) -> some View {
        let selected = type == t
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { type = t }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: t.sfSymbol)
                    .font(.system(size: 15))
                    .foregroundColor(selected ? .white : t.color)
                    .frame(width: 30, height: 30)
                    .background(selected ? t.color : t.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(t.label)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? PetCareTheme.primary : PetCareTheme.muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(t.color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? t.color : PetCareTheme.border, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var otherCard: some View {
        let selected = type == .other
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                type = .other
                customTypeFieldFocused = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15))
                    .foregroundColor(selected ? .white : PetCareTheme.muted)
                    .frame(width: 30, height: 30)
                    .background(selected ? Color.purple : PetCareTheme.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("Свой тип")
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? PetCareTheme.primary : PetCareTheme.muted)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.purple : PetCareTheme.border, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom type field

    private var customTypeField: some View {
        HStack(spacing: 10) {
            Image(systemName: "tag")
                .font(.system(size: 14))
                .foregroundColor(.purple)
                .frame(width: 28, height: 28)
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            TextField("Например: Прогулка", text: $customTypeName)
                .font(.system(size: 14))
                .focused($customTypeFieldFocused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(PetCareTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.5), lineWidth: 1.5)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Name field

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Название")
            HStack(spacing: 10) {
                Image(systemName: type.sfSymbol)
                    .font(.system(size: 14))
                    .foregroundColor(type.color)
                    .frame(width: 28, height: 28)
                    .background(type.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .animation(.easeInOut(duration: 0.15), value: type)
                TextField(type == .other && !customTypeName.isEmpty ? customTypeName : type.label, text: $title)
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border, lineWidth: 1))
        }
    }

    // MARK: - Date & time

    private var dateTimeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Когда")
            HStack(spacing: 8) {
                pickerCard(icon: "calendar", color: Color(hex: "#2196F3")) {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                pickerCard(icon: "clock", color: Color(hex: "#FF9800")) {
                    DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            }
        }
    }

    private func pickerCard<C: View>(icon: String, color: Color, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PetCareTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border, lineWidth: 1))
    }

    // MARK: - Pet row

    private var petRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Питомец")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pets) { pet in
                        let selected = currentPetId == pet.id
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { currentPetId = pet.id }
                        } label: {
                            HStack(spacing: 6) {
                                AvatarView(url: pet.photo, placeholder: "🐾", size: 20)
                                Text(pet.name)
                                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                                    .foregroundColor(selected ? .white : PetCareTheme.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selected ? PetCareTheme.primary : PetCareTheme.cardBackground)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selected ? Color.clear : PetCareTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(PetCareTheme.muted)
    }

    private func save() {
        let petName = pets.first(where: { $0.id == currentPetId })?.name ?? ""
        let resolvedTitle = title.trimmingCharacters(in: .whitespaces)
        let fallbackTitle = type == .other
            ? (customTypeName.trimmingCharacters(in: .whitespaces).isEmpty ? "Другое" : customTypeName.trimmingCharacters(in: .whitespaces))
            : type.label
        let r = Reminder(
            id: existingReminder?.id ?? UUID().uuidString,
            petId: currentPetId,
            petName: petName,
            type: type,
            customTypeName: type == .other ? customTypeName.trimmingCharacters(in: .whitespaces) : nil,
            title: resolvedTitle.isEmpty ? fallbackTitle : resolvedTitle,
            date: Self.dateFormatter.string(from: selectedDate),
            time: Self.timeFormatter.string(from: selectedTime),
            completed: false
        )
        onSave(r)
    }
}
