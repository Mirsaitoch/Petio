//
//  PetCareButton.swift
//  Petio
//
//  Кнопки дизайн-системы: основная, вторичная, иконка.
//

import SwiftUI

struct PetCarePrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(PetCareTheme.primaryForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .background(PetCareTheme.primary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .buttonStyle(.plain)
    }
}

struct PetCareIconButton: View {
    let icon: String
    let size: CGFloat
    let style: IconButtonStyle
    let action: () -> Void

    enum IconButtonStyle {
        case primaryOverlay
        case secondary
        case destructive
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.45))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
        }
        .background(backgroundColor)
        .clipShape(Circle())
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .primaryOverlay: return .white
        case .secondary: return PetCareTheme.muted
        case .destructive: return Color.red.opacity(0.9)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primaryOverlay: return Color.black.opacity(0.3)
        case .secondary: return PetCareTheme.secondary
        case .destructive: return Color.red.opacity(0.15)
        }
    }
}

struct PetCareDashedButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(title: String, icon: String? = "plus", action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                Text(title)
                    .font(.system(size: 14))
            }
            .foregroundColor(PetCareTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(PetCareTheme.primary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
        )
        .background(PetCareTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .buttonStyle(.plain)
    }
}

#Preview("Buttons") {
    VStack(spacing: 16) {
        PetCarePrimaryButton(title: "Сохранить") { }
        PetCareDashedButton(title: "Добавить питомца") { }
        HStack {
            PetCareIconButton(icon: "bell", size: 44, style: .primaryOverlay) { }
            PetCareIconButton(icon: "gearshape", size: 40, style: .secondary) { }
        }
    }
    .padding()
}
