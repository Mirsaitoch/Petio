//
//  AuthView.swift
//  Petio
//
//  Root container for authentication flow. Uses NavigationStack so
//  LoginView can push RegisterView.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LoginView()
                .environmentObject(AuthViewModel(authManager: authManager))
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth {
                dismiss()
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
