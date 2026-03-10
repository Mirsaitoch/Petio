//
//  ShelterDetailView.swift
//  Petio
//
//  Подробная информация о фонде или приюте.
//

import SwiftUI

struct ShelterDetailView: View {
    let shelter: Shelter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroSection
                contentSection
            }
            .padding(.bottom, 32)
        }
        .background(PetCareTheme.background)
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

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
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
                                .font(.system(size: 60))
                                .foregroundColor(PetCareTheme.muted)
                        )
                }
            }
            .frame(height: 220)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(shelter.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                Text(shelter.tagline)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            metaRow
            descriptionSection
            tagsSection
            needsSection
            contactSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var metaRow: some View {
        HStack(spacing: 12) {
            metaBadge(icon: "tag", text: shelter.category, color: shelter.category == "Приют" ? .orange : PetCareTheme.primary)
            metaBadge(icon: "mappin", text: shelter.city, color: PetCareTheme.primary)
            metaBadge(icon: "calendar", text: "c \(shelter.founded)", color: PetCareTheme.primary)
            Spacer()
        }
    }

    private func metaBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(PetCareTheme.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("О нас", systemImage: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PetCareTheme.primary)
            Text(shelter.longDescription)
                .font(.system(size: 14))
                .foregroundColor(PetCareTheme.primary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .petCareCardStyle()
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Направления", systemImage: "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PetCareTheme.primary)
            FlowLayout(spacing: 8) {
                ForEach(shelter.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(PetCareTheme.secondary)
                        .clipShape(Capsule())
                        .foregroundColor(PetCareTheme.primary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .petCareCardStyle()
    }

    private var needsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Чем помочь", systemImage: "heart")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PetCareTheme.primary)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(shelter.needs, id: \.self) { need in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(PetCareTheme.primary)
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        Text(need)
                            .font(.system(size: 14))
                            .foregroundColor(PetCareTheme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .petCareCardStyle()
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Контакты", systemImage: "phone")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PetCareTheme.primary)

            if let phoneURL = URL(string: "tel://\(shelter.phone.filter { $0.isNumber || $0 == "+" })") {
                Link(destination: phoneURL) {
                    contactRow(icon: "phone.fill", text: shelter.phone, color: .green)
                }
                .buttonStyle(.plain)
            }

            let urlString = shelter.website.hasPrefix("http") ? shelter.website : "https://\(shelter.website)"
            if let siteURL = URL(string: urlString) {
                Link(destination: siteURL) {
                    contactRow(icon: "globe", text: shelter.website, color: .blue)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .petCareCardStyle()
    }

    private func contactRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(PetCareTheme.primary)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11))
                .foregroundColor(PetCareTheme.muted)
        }
    }
}
