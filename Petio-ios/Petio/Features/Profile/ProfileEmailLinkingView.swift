//
//  ProfileEmailLinkingView.swift
//  Petio
//
//  Sheet for linking email from profile settings.
//

import SwiftUI

struct ProfileEmailLinkingView: View {
    let authManager: AuthManager
    let onComplete: () -> Void

    @State private var viewModel: AuthViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ProfileEmailLinkingContent(viewModel: vm, onComplete: onComplete)
            } else {
                Color.clear
            }
        }
        .task {
            if viewModel == nil {
                viewModel = AuthViewModel(authManager: authManager)
            }
        }
    }
}

private struct ProfileEmailLinkingContent: View {
    @ObservedObject var viewModel: AuthViewModel
    let onComplete: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var isValid: Bool {
        !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isVerifyingEmail {
                    verificationView
                } else {
                    formView
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onComplete() }
                }
            }
        }
    }

    private var verificationView: some View {
        EmailVerificationView(authViewModel: viewModel)
            .onChange(of: viewModel.showEmailLinking) { _, show in
                // verifyEmail sets showEmailLinking = false on success
                if !show {
                    onComplete()
                }
            }
    }

    private var formView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 48))
                    .foregroundStyle(PetCareTheme.primary)

                Text("Привязать email")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PetCareTheme.primary)

                Text("Добавьте email и пароль для входа на других устройствах")
                    .font(.system(size: 15))
                    .foregroundStyle(PetCareTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 32)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PetCareTheme.muted)
                    TextField("Ваша почта", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(14)
                        .background(PetCareTheme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Пароль")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PetCareTheme.muted)
                    SecureField("Минимум 6 символов", text: $password)
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
                                !confirmPassword.isEmpty && password != confirmPassword
                                    ? Color.red : PetCareTheme.border
                            )
                        )
                    if !confirmPassword.isEmpty && password != confirmPassword {
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
                title: viewModel.isLoading ? "Отправка..." : "Привязать"
            ) {
                Task { await viewModel.linkEmail(email: email, password: password) }
            }
            .disabled(!isValid || viewModel.isLoading)
            .opacity(isValid && !viewModel.isLoading ? 1 : 0.6)
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}
