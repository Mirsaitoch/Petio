//
//  ContentView.swift
//  Petio
//
//  Entry point with device-based auth flow.
//  Routes to DeviceLoginView → EmailLinkingPromptView → AppTabView
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let authViewModel = AuthViewModel(authManager: authManager)
        return AuthContainer(authViewModel: authViewModel)
            .environmentObject(appState)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(AppState(api: MockAPIClient()))
}
