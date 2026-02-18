//
//  BottomSheet.swift
//  Petio
//
//  Модальное окно снизу (как в дизайне).
//

import SwiftUI

struct BottomSheet<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(PetCareTheme.muted.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PetCareTheme.primary)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(PetCareTheme.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                content()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
