//
//  LoginView.swift
//  Petio
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var viewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 60))
                        .foregroundColor(PetCareTheme.primary)
                    Text("Petio")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(PetCareTheme.primary)
                    Text("Забота о питомцах")
                        .font(.system(size: 16))
                        .foregroundColor(PetCareTheme.muted)
                }
                .padding(.top, 60)

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
                        Text("Пароль")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PetCareTheme.muted)
                        SecureField("••••••••", text: $password)
                            .textContentType(.password)
                            .padding(14)
                            .background(PetCareTheme.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PetCareTheme.border))
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    PetCarePrimaryButton(title: viewModel.isLoading ? "Вход..." : "Войти") {
                        Task { await viewModel.login(email: email, password: password) }
                    }
                    .disabled(viewModel.isLoading || email.isEmpty || password.isEmpty)
                    .opacity(viewModel.isLoading ? 0.7 : 1)
                }
                .padding(.horizontal, 24)

                // Register link
                NavigationLink {
                    RegisterView()
                        .environmentObject(viewModel)
                } label: {
                    HStack(spacing: 4) {
                        Text("Нет аккаунта?")
                            .foregroundColor(PetCareTheme.muted)
                        Text("Зарегистрироваться")
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
        LoginView()
            .environmentObject(AuthViewModel(authManager: AuthManager()))
    }
}
