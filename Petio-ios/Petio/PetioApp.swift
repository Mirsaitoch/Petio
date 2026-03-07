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
            ZStack(alignment: .top) {
                // Основной контент
                ContentView()
                    .environmentObject(container.authManager)
                    .environmentObject(container.appState)
                    .environmentObject(container.appState.networkMonitor)

                // Баннер офлайна сверху
                OfflineIndicatorView()
                    .environmentObject(container.appState.networkMonitor)
            }
        }
    }
}
