//
//  PetPickerPopup.swift
//  Petio
//
//  Компактный поп-ап для выбора питомца.
//

import SwiftUI

struct PetPickerPopup: View {
    let pets: [Pet]
    let onSelect: (Pet) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Text("Выберите питомца")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PetCareTheme.primary)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                VStack(spacing: 8) {
                    ForEach(pets) { pet in
                        Button {
                            onSelect(pet)
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(
                                    url: pet.photo,
                                    imageName: speciesImageName(pet.species),
                                    size: 40
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pet.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(PetCareTheme.primary)
                                    Text(pet.species)
                                        .font(.system(size: 12))
                                        .foregroundStyle(PetCareTheme.muted)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PetCareTheme.muted)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(PetCareTheme.cardBackground)
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(PetCareTheme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(PetCareTheme.background)
            .clipShape(.rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }
}
