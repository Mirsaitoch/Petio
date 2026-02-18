//
//  PetCareCard.swift
//  Petio
//
//  Карточки: базовая, с бордером, для списков.
//

import SwiftUI

struct PetCareCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(PetCareTheme.border, lineWidth: 1))
    }
}

struct PetCareInfoCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(PetCareTheme.primary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(PetCareTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .petCareCardStyle()
    }
}

struct PetCareReminderRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let completed: Bool
    let onToggle: (() -> Void)?
    let onDelete: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        completed: Bool,
        onToggle: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.completed = completed
        self.onToggle = onToggle
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 12) {
            if let onToggle = onToggle {
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .stroke(PetCareTheme.primary.opacity(0.3), lineWidth: 2)
                            .frame(width: 28, height: 28)
                        if completed {
                            Circle()
                                .fill(PetCareTheme.primary)
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                    .strikethrough(completed)
                    .foregroundColor(completed ? PetCareTheme.muted : PetCareTheme.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(PetCareTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            if onDelete != nil {
                Button(action: { onDelete?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(PetCareTheme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .petCareCardStyle()
        .opacity(completed ? 0.7 : 1)
    }
}
