//
//  SheltersListView.swift
//  Petio
//
//  Список фондов и приютов.
//

import SwiftUI

struct SheltersListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path: [AppRoute] = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(Shelter.all) { shelter in
                    NavigationLink(value: AppRoute.shelterDetail(shelter)) {
                        ShelterCardView(shelter: shelter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(PetCareTheme.background)
        .navigationTitle("Фонды и приюты")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PetCareTheme.primary)
                }
            }
        }
    }
}

struct ShelterCardView: View {
    let shelter: Shelter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: URL(string: shelter.imageURL)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(PetCareTheme.secondary)
                        .overlay(
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 36))
                                .foregroundColor(PetCareTheme.muted)
                        )
                }
            }
            .frame(height: 140)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(shelter.category)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(shelter.category == "Приют" ? .orange : PetCareTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (shelter.category == "Приют" ? Color.orange : PetCareTheme.primary).opacity(0.12)
                        )
                        .clipShape(Capsule())

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                            .foregroundColor(PetCareTheme.muted)
                        Text(shelter.city)
                            .font(.system(size: 11))
                            .foregroundColor(PetCareTheme.muted)
                    }
                }

                Text(shelter.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)

                Text(shelter.description)
                    .font(.system(size: 13))
                    .foregroundColor(PetCareTheme.muted)
                    .lineLimit(2)
            }
            .padding(14)
        }
        .petCareCardStyle()
    }
}
