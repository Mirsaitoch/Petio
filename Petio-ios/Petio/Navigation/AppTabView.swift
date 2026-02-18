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
        ZStack(alignment: .bottomTrailing) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .health:
                    HealthView()
                case .feed:
                    FeedView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !showChat {
                tabBar
            }

            if !showChat {
                chatFloatingButton
            }
        }
        .fullScreenCover(isPresented: $showChat) {
            ChatView(onDismiss: { showChat = false })
        }
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.rawValue) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                                .foregroundColor(selectedTab == tab ? PetCareTheme.primary : PetCareTheme.muted)
                            Text(tab.title)
                                .font(.system(size: 10))
                                .foregroundColor(selectedTab == tab ? PetCareTheme.primary : PetCareTheme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .background(PetCareTheme.cardBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(PetCareTheme.border),
                alignment: .top
            )
        }
        .frame(height: 70)
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
