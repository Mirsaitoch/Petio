//
//  PetCareHeader.swift
//  Petio
//
//  Шапки экранов: градиентная, простая, с кнопкой назад.
//

import SwiftUI

struct PetCareGradientHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            PetCareTheme.primary
            VStack(alignment: .leading, spacing: 4) {
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .overlay(alignment: .topTrailing) {
                trailing
                    .padding(.trailing, 20)
                    .padding(.top, 12)
            }
        }
        .frame(height: 120)
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32,
                topTrailingRadius: 0
            )
        )
    }
}

extension PetCareGradientHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

struct PetCareBackHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PetCareIconButton(icon: "chevron.left", size: 36, style: .primaryOverlay) {
                onBack()
            }
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(PetCareTheme.primary)
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                topTrailingRadius: 0
            )
        )
    }
}

struct PetCareSectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?
    let foregroundColor: Color?

    init(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        foregroundColor: Color? = PetCareTheme.primary
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
        self.foregroundColor = foregroundColor
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(foregroundColor)
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(.system(size: 14))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(foregroundColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
