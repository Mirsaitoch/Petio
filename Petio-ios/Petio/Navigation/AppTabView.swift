//
//  AppTabView.swift
//  Petio
//
//  Главный таб-навигатор и плавающая кнопка чата.
//

import SwiftUI

enum AppTab: Int, CaseIterable {
    case home = 0
    case pets
    case feed
    case chat
    case profile

    var title: String {
        switch self {
        case .home: return "Главная"
        case .pets: return "Питомцы"
        case .feed: return "Лента"
        case .chat: return "AI-чат"
        case .profile: return "Профиль"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .pets: return "pawprint.fill"
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

            NavigationStack {
                PetListViewModel()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .petDetail(let id):
                            PetDetailView(petId: id)
                        case .petReminders(let id):
                            PetRemindersView(petId: id)
                        case .petWeight(let id):
                            PetWeightView(petId: id)
                        case .petDiary(let id):
                            PetDiaryView(petId: id)
                        case .shelters:
                            SheltersListView()
                        case .shelterDetail(let shelter):
                            ShelterDetailView(shelter: shelter)
                        default:
                            EmptyView()
                        }
                    }
            }
            .tabItem {
                Label(AppTab.pets.title, systemImage: AppTab.pets.icon)
            }
            .tag(AppTab.pets)

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
