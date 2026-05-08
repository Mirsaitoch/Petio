//
//  EmailVerificationView.swift
//  Petio
//
//  Email verification code input view.
//

import SwiftUI

struct EmailVerificationView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var code = ""

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Подтвердите email")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let email = authViewModel.currentEmail {
                    Text("Мы отправили код на \(email)")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Мы отправили код на вашу почту")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 12) {
                TextField("Код верификации (6 цифр)", text: $code)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .font(.title3)
                    .onChange(of: code) { newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count > 6 {
                            code = String(filtered.prefix(6))
                        } else {
                            code = filtered
                        }
                    }
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
                Button(action: verifyButtonTapped) {
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Подтвердить")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(code.count != 6 || authViewModel.isLoading)

                Button(action: resendButtonTapped) {
                    Text("Отправить код заново")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.blue)
            }

            Spacer()
        }
        .padding()
    }

    private func verifyButtonTapped() {
        Task {
            await authViewModel.verifyEmail(code: code)
            if authViewModel.errorMessage == nil {
                // Success - will navigate to main app
            }
        }
    }

    private func resendButtonTapped() {
        // TODO: Implement resend code functionality
        authViewModel.errorMessage = "Функция повторной отправки кода будет реализована позже"
    }
}

#Preview {
    EmailVerificationView(authViewModel: AuthViewModel(authManager: AuthManager.shared))
}
