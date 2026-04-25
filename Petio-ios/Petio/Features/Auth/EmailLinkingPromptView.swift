//
//  EmailLinkingPromptView.swift
//  Petio
//
//  Email linking form for converting anonymous account to password-protected account.
//

import SwiftUI

struct EmailLinkingPromptView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Защитить аккаунт")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Привяжите email и пароль для безопасного доступа на других устройствах")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)

                SecureField("Пароль", text: $password)
                    .textFieldStyle(.roundedBorder)

                SecureField("Подтвердить пароль", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
            }

            VStack(spacing: 12) {
                Button(action: continueButtonTapped) {
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Продолжить")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(!isValid || authViewModel.isLoading)

                Button(action: skipButtonTapped) {
                    Text("Пропустить")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.blue)
            }

            Spacer()
        }
        .padding()
    }

    private var isValid: Bool {
        !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 8
    }

    private func continueButtonTapped() {
        Task {
            await authViewModel.linkEmail(email: email, password: password)
            if authViewModel.errorMessage == nil {
                // Success - will navigate to verification view
            }
        }
    }

    private func skipButtonTapped() {
        authViewModel.showEmailLinking = false
    }
}

#Preview {
    EmailLinkingPromptView(authViewModel: AuthViewModel(authManager: AuthManager.shared))
}
