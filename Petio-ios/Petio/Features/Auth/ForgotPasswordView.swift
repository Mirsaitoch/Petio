//
//  ForgotPasswordView.swift
//  Petio
//
//  Sends a 6-digit reset code to the user's email.
//

import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 48))
                        .foregroundStyle(PetCareTheme.primary)

                    Text("Восстановление пароля")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(PetCareTheme.primary)

                    Text("Введите email, и мы отправим код для сброса пароля")
                        .font(.system(size: 15))
                        .foregroundStyle(PetCareTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PetCareTheme.muted)
                    TextField("Ваша почта", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .padding(14)
                        .background(PetCareTheme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border))
                }
                .padding(.horizontal, 24)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                PetCarePrimaryButton(
                    title: viewModel.isLoading ? "Отправка..." : "Отправить код"
                ) {
                    Task { await viewModel.forgotPassword(email: email) }
                }
                .disabled(viewModel.isLoading || email.isEmpty)
                .opacity(viewModel.isLoading || email.isEmpty ? 0.6 : 1)
                .padding(.horizontal, 24)

                Spacer()
            }
            .background(PetCareTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .onAppear {
                if let prefilled = viewModel.currentEmail {
                    email = prefilled
                }
                viewModel.errorMessage = nil
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthViewModel(authManager: AuthManager()))
}
