//
//  ContentView.swift
//  Petio
//
//  Auth gate: shows AuthView when not authenticated, AppTabView when authenticated.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                AppTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth {
                Task { await appState.loadAll() }
            } else {
                appState.resetUserSession()
            }
        }
        .task {
            if authManager.isAuthenticated {
                await appState.loadAll()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(AppState(api: MockAPIClient()))
}
