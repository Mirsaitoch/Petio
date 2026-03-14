//
//  AuthPromptSheet.swift
//  Petio
//
//  Bottom sheet shown when a guest attempts a protected action.
//

import SwiftUI

struct AuthPromptSheet: View {
    @Binding var isPresented: Bool
    let message: String
    @State private var showAuth = false

    var body: some View {
        VStack(spacing: 24) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            // Illustration
            ZStack {
                Circle()
                    .fill(PetCareTheme.secondary)
                    .frame(width: 80, height: 80)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 36))
                    .foregroundColor(PetCareTheme.primary)
            }

            // Text
            VStack(spacing: 8) {
                Text("Нужен аккаунт")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(PetCareTheme.primary)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Buttons
            VStack(spacing: 10) {
                Button {
                    isPresented = false
                    showAuth = true
                } label: {
                    Text("Войти / Зарегистрироваться")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PetCareTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button {
                    isPresented = false
                } label: {
                    Text("Позже")
                        .font(.system(size: 15))
                        .foregroundColor(PetCareTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(PetCareTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.hidden)
        .fullScreenCover(isPresented: $showAuth) {
            AuthView()
        }
    }
}
