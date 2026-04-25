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
                // Device login flow
                if authViewModel.showEmailLinking {
                    EmailLinkingPromptView(authViewModel: authViewModel)
                } else {
                    DeviceLoginView(authViewModel: authViewModel)
                }
            } else {
                // Main app flow
                AppTabView()
                    .task {
                        await appState.loadAll()
                    }
            }
        }
    }
}

#Preview {
    AuthContainer(authViewModel: AuthViewModel(authManager: AuthManager.shared))
        .environmentObject(AppState(api: MockAPIClient()))
}
