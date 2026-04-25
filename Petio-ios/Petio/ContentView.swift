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
    @State private var authViewModel: AuthViewModel?

    init() {
        print("[CONTENT_VIEW_INIT] ContentView initializing")
    }

    var body: some View {
        let _ = print("[CONTENT_VIEW_BODY] computing body, authViewModel=\(authViewModel == nil ? "nil" : "exists")")
        return Group {
            if let vm = authViewModel {
                AuthContainer(authViewModel: vm)
                    .environmentObject(appState)
            } else {
                Color.white
                    .ignoresSafeArea()
            }
        }
        .task {
            print("[CONTENT_VIEW] task: authViewModel is \(authViewModel == nil ? "nil" : "initialized")")
            if authViewModel == nil {
                print("[CONTENT_VIEW] task: creating AuthViewModel with authManager.isAuthenticated=\(authManager.isAuthenticated)")
                authViewModel = AuthViewModel(authManager: authManager)
                print("[CONTENT_VIEW] task: AuthViewModel created: \(authViewModel == nil ? "FAILED" : "SUCCESS")")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(AppState(api: MockAPIClient()))
}
