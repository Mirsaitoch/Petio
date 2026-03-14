//
//  AddPetSheet.swift
//  Petio
//

import SwiftUI

struct AddPetSheet: View {
    let onSave: (Pet) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var species = "Собака"
    @State private var customSpecies = ""
    @State private var breed = ""
    @State private var birthDate = Date()
    @State private var weight = ""
    @State private var features = ""
    @State private var photoPath: String? = nil
    @FocusState private var focusedField: Field?

    private enum Field { case name, breed, weight, features, customSpecies }

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

    private var selectedImageName: String { speciesImageName(species) }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
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
                Text("Новый питомец")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
                Spacer()
                Button(action: save) {
                    Text("Добавить")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(canSave ? PetCareTheme.primary : PetCareTheme.muted)
                }
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    avatarSection
                    nameSection
                    speciesSection
                    if species == "Другое" { customSpeciesField }
                    breedSection
                    birthdateSection
                    weightSection
                    featuresSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(PetCareTheme.background)
        .presentationDetents([.large])
        .presentationCornerRadius(24)
        .presentationDragIndicator(.hidden)
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 8) {
            AvatarPickerButton(
                photoPath: $photoPath,
                imageName: selectedImageName,
                size: 80
            )
            Text("Нажмите, чтобы добавить фото")
                .font(.system(size: 12))
                .foregroundColor(PetCareTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Имя *")
            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundColor(PetCareTheme.primary)
                    .frame(width: 28, height: 28)
                    .background(PetCareTheme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                TextField("Введите имя питомца", text: $name)
                    .focused($focusedField, equals: .name)
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                focusedField == .name ? PetCareTheme.primary.opacity(0.5) : PetCareTheme.border,
                lineWidth: focusedField == .name ? 1.5 : 1
            ))
            .animation(.easeInOut(duration: 0.15), value: focusedField == .name)
        }
    }

    // MARK: - Species

    private var speciesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Вид")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(speciesOptions, id: \.self) { option in
                    let selected = species == option
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            species = option
                        }
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? PetCareTheme.primary : PetCareTheme.border,
                                        lineWidth: selected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Custom species

    private var customSpeciesField: some View {
        HStack(spacing: 10) {
            Image(systemName: "pawprint")
                .font(.system(size: 13))
                .foregroundColor(.purple)
                .frame(width: 28, height: 28)
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            TextField("Укажите вид", text: $customSpecies)
                .focused($focusedField, equals: .customSpecies)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(PetCareTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.5), lineWidth: 1.5))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Breed

    private var breedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Порода")
            HStack(spacing: 10) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#4CAF50"))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: "#4CAF50").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                TextField("Порода (необязательно)", text: $breed)
                    .focused($focusedField, equals: .breed)
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

    // MARK: - Birth date

    private var birthdateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Дата рождения")
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
    }

    // MARK: - Weight

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Вес (кг)")
            HStack(spacing: 10) {
                Image(systemName: "scalemass")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#FF9800"))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: "#FF9800").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                TextField("0.0", text: $weight)
                    .focused($focusedField, equals: .weight)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.primary)
                    .onChange(of: weight) { _, new in
                        let filtered = new.filter { $0.isNumber || $0 == "." || $0 == "," }
                        if filtered != new { weight = filtered }
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border, lineWidth: 1))
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Особенности")
            HStack(spacing: 10) {
                Image(systemName: "star")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#9C27B0"))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: "#9C27B0").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                TextField("Аллергия, любит играть...", text: $features)
                    .focused($focusedField, equals: .features)
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border, lineWidth: 1))
            Text("Через запятую")
                .font(.system(size: 11))
                .foregroundColor(PetCareTheme.muted)
        }
    }

    // MARK: - Helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(PetCareTheme.muted)
    }

    private func save() {
        let birthString = Self.isoFormatter.string(from: birthDate)
        let trimmedCustom = customSpecies.trimmingCharacters(in: .whitespaces)
        let finalSpecies = species == "Другое"
            ? (trimmedCustom.isEmpty ? "Другое" : trimmedCustom)
            : species
        let normalizedWeight = weight.replacingOccurrences(of: ",", with: ".")
        let pet = Pet(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            species: finalSpecies,
            breed: breed.isEmpty ? "Не указана" : breed,
            age: PetAgeCalculator.computedAge(from: birthString),
            weight: max(0, Double(normalizedWeight) ?? 0),
            photo: photoPath,
            birthDate: birthString,
            vaccinations: [],
            treatments: [],
            features: features.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        )
        onSave(pet)
    }
}
