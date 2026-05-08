//
//  ProfileLoginView.swift
//  Petio
//
//  Sheet for logging into an existing account from profile settings.
//

import SwiftUI

struct ProfileLoginView: View {
    let authManager: AuthManager
    let onComplete: () -> Void

    @State private var viewModel: AuthViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ProfileLoginContent(viewModel: vm, onComplete: onComplete)
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

private struct ProfileLoginContent: View {
    @ObservedObject var viewModel: AuthViewModel
    let onComplete: () -> Void

    @State private var email = ""
    @State private var password = ""

    private var isValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(PetCareTheme.primary)

                    Text("Войти в аккаунт")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(PetCareTheme.primary)

                    Text("Введите email и пароль от существующего аккаунта")
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
                            .textContentType(.none)
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
                        SecureField("Ваш пароль", text: $password)
                            .textContentType(.none)
                            .padding(14)
                            .background(PetCareTheme.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border))
                    }

                    HStack {
                        Spacer()
                        Button {
                            viewModel.currentEmail = email.isEmpty ? nil : email
                            viewModel.passwordRecoverySheet = .forgotPassword
                        } label: {
                            Text("Забыли пароль?")
                                .font(.system(size: 14))
                                .foregroundStyle(PetCareTheme.primary)
                        }
                        .buttonStyle(.plain)
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
                    title: viewModel.isLoading ? "Вход..." : "Войти"
                ) {
                    Task { await viewModel.login(email: email, password: password) }
                }
                .disabled(!isValid || viewModel.isLoading)
                .opacity(isValid && !viewModel.isLoading ? 1 : 0.6)
                .padding(.horizontal, 24)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onComplete() }
                }
            }
            .onChange(of: viewModel.didLogin) { _, didLogin in
                if didLogin {
                    onComplete()
                }
            }
            .sheet(item: $viewModel.passwordRecoverySheet) { sheet in
                switch sheet {
                case .forgotPassword:
                    ForgotPasswordView()
                        .environmentObject(viewModel)
                case .resetPassword:
                    ResetPasswordView()
                        .environmentObject(viewModel)
                }
            }
        }
    }
}
