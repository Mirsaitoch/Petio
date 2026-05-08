//
//  ResetPasswordView.swift
//  Petio
//
//  Enter reset code + new password after receiving the email.
//

import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showSuccess = false

    private var passwordsMatch: Bool { newPassword == confirmPassword }
    private var canSubmit: Bool {
        code.count == 6 && newPassword.count >= 6 && passwordsMatch && !viewModel.isLoading
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if showSuccess {
                    successContent
                } else {
                    formContent
                }
                Spacer()
            }
            .background(PetCareTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .onAppear { viewModel.errorMessage = nil }
        }
    }

    private var formContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 48))
                    .foregroundStyle(PetCareTheme.primary)

                Text("Новый пароль")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PetCareTheme.primary)

                if let email = viewModel.currentEmail {
                    Text("Введите код из письма на \(email)")
                        .font(.system(size: 15))
                        .foregroundStyle(PetCareTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, 32)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Код из письма")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PetCareTheme.muted)
                    TextField("6 цифр", text: $code)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title3)
                        .padding(14)
                        .background(PetCareTheme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border))
                        .onChange(of: code) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            code = String(filtered.prefix(6))
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Новый пароль")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PetCareTheme.muted)
                    SecureField("Минимум 6 символов", text: $newPassword)
                        .padding(14)
                        .background(PetCareTheme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Подтвердите пароль")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PetCareTheme.muted)
                    SecureField("Повторите пароль", text: $confirmPassword)
                        .padding(14)
                        .background(PetCareTheme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(
                                !confirmPassword.isEmpty && !passwordsMatch ? Color.red : PetCareTheme.border
                            )
                        )
                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Пароли не совпадают")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }
                }
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
                title: viewModel.isLoading ? "Сохранение..." : "Сбросить пароль"
            ) {
                Task {
                    await viewModel.resetPassword(
                        email: viewModel.currentEmail ?? "",
                        code: code,
                        newPassword: newPassword
                    )
                    if viewModel.errorMessage == nil {
                        showSuccess = true
                    }
                }
            }
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.6)
            .padding(.horizontal, 24)
        }
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Пароль изменён")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PetCareTheme.primary)

            Text("Теперь вы можете войти с новым паролем")
                .font(.system(size: 15))
                .foregroundStyle(PetCareTheme.muted)

            PetCarePrimaryButton(title: "Готово") {
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .padding(.top, 64)
    }
}

#Preview {
    ResetPasswordView()
        .environmentObject(AuthViewModel(authManager: AuthManager()))
}
