//
//  ContentView.swift
//  Petio
//
//  Точка входа UI: табы и общее состояние приложения.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        AppTabView()
            .environmentObject(appState)
    }
}

#Preview {
    ContentView()
}
