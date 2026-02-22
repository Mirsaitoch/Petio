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
    case profile

    var title: String {
        switch self {
        case .home: return "Главная"
        case .health: return "Здоровье"
        case .feed: return "Лента"
        case .profile: return "Профиль"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .health: return "heart.fill"
        case .feed: return "newspaper.fill"
        case .profile: return "person.fill"
        }
    }
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showChat = false
    @EnvironmentObject private var app: AppState

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(AppTab.home.title, systemImage: AppTab.home.icon)
                }
                .tag(AppTab.home)

            HealthView()
                .tabItem {
                    Label(AppTab.health.title, systemImage: AppTab.health.icon)
                }
                .tag(AppTab.health)

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
        .overlay(alignment: .bottomTrailing) {
            if !showChat {
                chatFloatingButton
            }
        }
        .fullScreenCover(isPresented: $showChat) {
            ChatView(onDismiss: { showChat = false })
        }
    }

    private var chatFloatingButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showChat = true
                } label: {
                    Image(systemName: "message.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(PetCareTheme.primary)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.bottom, 78)
            }
        }
        .allowsHitTesting(true)
    }
}
