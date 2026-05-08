//
//  AuthView.swift
//  Petio
//
//  Root container for authentication flow. Uses NavigationStack so
//  LoginView can push RegisterView. Handles verification after register.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AuthViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                AuthViewContent(viewModel: vm)
            } else {
                Color.clear
            }
        }
        .task {
            if viewModel == nil {
                viewModel = AuthViewModel(authManager: authManager)
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth {
                dismiss()
            }
        }
    }
}

private struct AuthViewContent: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        if viewModel.isVerifyingEmail {
            EmailVerificationView(authViewModel: viewModel)
        } else {
            NavigationStack {
                LoginView()
                    .environmentObject(viewModel)
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
