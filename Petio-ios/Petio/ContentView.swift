//
//  ContentView.swift
//  Petio
//
//  Entry point. Always shows AppTabView — no auth gate.
//  AuthView is presented as a sheet from AuthPromptSheet or ProfileView.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        AppTabView()
            .task {
                await appState.loadAll()
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuth in
                if isAuth {
                    Task {
                        await appState.loadAll()
                    }
                } else {
                    appState.resetUserSession()
                    Task { await appState.loadAll() }
                }
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(AppState(api: MockAPIClient()))
}
