//
//  RegisterView.swift
//  Petio
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool { password == confirmPassword }
    private var isUsernameValid: Bool {
        username.trimmingCharacters(in: .whitespaces).isEmpty ||
        username.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil
    }
    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6 && passwordsMatch && isUsernameValid && !viewModel.isLoading
    }

    private var usernamePlaceholder: String {
        AuthViewModel.generateZooUsername()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Создать аккаунт")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(PetCareTheme.primary)
                    Text("Присоединитесь к сообществу владельцев питомцев")
                        .font(.system(size: 15))
                        .foregroundColor(PetCareTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PetCareTheme.muted)
                        TextField("you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(14)
                            .background(PetCareTheme.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("Никнейм")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(PetCareTheme.muted)
                            Text("· необязательно")
                                .font(.system(size: 12))
                                .foregroundColor(PetCareTheme.muted.opacity(0.6))
                        }
                        HStack(spacing: 0) {
                            Text("@")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(PetCareTheme.muted)
                                .padding(.leading, 14)
                            TextField(usernamePlaceholder, text: $username)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding(14)
                        }
                        .background(PetCareTheme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(
                                !isUsernameValid ? Color.red : PetCareTheme.border
                            )
                        )
                        if !isUsernameValid {
                            Text("Только буквы, цифры, - и _")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        } else if username.isEmpty {
                            Text("Оставьте пустым — получите случайный ник в зоо-стиле")
                                .font(.system(size: 12))
                                .foregroundColor(PetCareTheme.muted.opacity(0.7))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Пароль")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PetCareTheme.muted)
                        SecureField("Минимум 6 символов", text: $password)
                            .textContentType(.newPassword)
                            .padding(14)
                            .background(PetCareTheme.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Подтвердите пароль")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PetCareTheme.muted)
                        SecureField("Повторите пароль", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding(14)
                            .background(PetCareTheme.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(
                                    !confirmPassword.isEmpty && !passwordsMatch
                                        ? Color.red : PetCareTheme.border
                                )
                            )
                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Пароли не совпадают")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    PetCarePrimaryButton(
                        title: viewModel.isLoading ? "Регистрация..." : "Зарегистрироваться"
                    ) {
                        Task { await viewModel.register(email: email, password: password, username: username) }
                    }
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.6)
                }
                .padding(.horizontal, 24)

                // Login link
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Text("Уже есть аккаунт?")
                            .foregroundColor(PetCareTheme.muted)
                        Text("Войти")
                            .foregroundColor(PetCareTheme.primary)
                            .fontWeight(.medium)
                    }
                    .font(.system(size: 15))
                }

                Spacer()
            }
        }
        .background(PetCareTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel(authManager: AuthManager()))
    }
}
