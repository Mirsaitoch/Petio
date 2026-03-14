//
//  AppTabView.swift
//  Petio
//
//  Главный таб-навигатор и плавающая кнопка чата.
//

import SwiftUI

enum AppTab: Int, CaseIterable {
    case home = 0
    case health
    case feed
    case chat
    case profile

    var title: String {
        switch self {
        case .home: return "Главная"
        case .health: return "Здоровье"
        case .feed: return "Лента"
        case .chat: return "AI-чат"
        case .profile: return "Профиль"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .health: return "heart.fill"
        case .feed: return "newspaper.fill"
        case .chat: return "apple.intelligence"
        case .profile: return "person.fill"
        }
    }
}

struct AppTabView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        TabView(selection: $app.selectedTab) {
            HomeView(selectedTab: $app.selectedTab)
                .tabItem {
                    Label(AppTab.home.title, systemImage: AppTab.home.icon)
                }
                .tag(AppTab.home)

            HealthView()
                .tabItem {
                    Label(AppTab.health.title, systemImage: AppTab.health.icon)
                }
                .tag(AppTab.health)

            ChatView()
                .tabItem {
                    Label(AppTab.chat.title, systemImage: AppTab.chat.icon)
                }
                .tag(AppTab.chat)
            
            FeedView()
                .tabItem {
                    Label(AppTab.feed.title, systemImage: AppTab.feed.icon)
                }
                .tag(AppTab.feed)

            ProfileView()
                .tabItem {
                    Label(AppTab.profile.title, systemImage: AppTab.profile.icon)
                }
                .tag(AppTab.profile)
        }
        .tint(PetCareTheme.primary)
    }
}
