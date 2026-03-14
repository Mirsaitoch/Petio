//
//  AppContainer.swift
//  Petio
//
//  Dependency container. Created once in PetioApp, wires AuthManager → HTTPAPIClient → AppState.
//

import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let authManager: AuthManager
    let appState: AppState

    init() {
        let auth = AuthManager()
        let client = HTTPAPIClient(authManager: auth)
        self.authManager = auth
        self.appState = AppState(api: client, authManager: auth)
    }
}
