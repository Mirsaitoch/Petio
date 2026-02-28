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

    var body: some View {
        NavigationStack {
            LoginView()
                .environmentObject(AuthViewModel(authManager: authManager))
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
