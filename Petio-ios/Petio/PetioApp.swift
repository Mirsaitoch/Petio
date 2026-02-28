//
//  PetioApp.swift
//  Petio
//

import SwiftUI

@main
struct PetioApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container.authManager)
                .environmentObject(container.appState)
        }
    }
}
