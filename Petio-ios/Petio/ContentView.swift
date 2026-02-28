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
                    .task { await appState.loadAll() }
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(AppState(api: MockAPIClient()))
}
