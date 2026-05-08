//
//  AuthContainer.swift
//  Petio
//
//  Container for auth flow routing (DeviceLogin → EmailLinking → App)
//

import SwiftUI

struct AuthContainer: View {
    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if !authViewModel.isAuthenticated {
                if authViewModel.isVerifyingEmail {
                    EmailVerificationView(authViewModel: authViewModel)
                } else if authViewModel.showEmailLinking {
                    EmailLinkingPromptView(authViewModel: authViewModel)
                } else {
                    DeviceLoginView(authViewModel: authViewModel)
                }
            } else {
                AppTabView()
                    .task {
                        print("[AUTH] AppTabView task: starting loadAll()")
                        await appState.loadAll()
                        print("[AUTH] AppTabView task: loadAll() completed")
                    }
            }
        }
        .onAppear {
            print("[AUTH_CONTAINER] appeared, isAuthenticated=\(authViewModel.isAuthenticated)")
            print("[AUTH_CONTAINER] showEmailLinking=\(authViewModel.showEmailLinking), isVerifyingEmail=\(authViewModel.isVerifyingEmail)")
        }
    }
}

#Preview {
    AuthContainer(authViewModel: AuthViewModel(authManager: AuthManager.shared))
        .environmentObject(AppState(api: MockAPIClient()))
}
