//
//  HomeView.swift
//  Petio
//
//  Главный экран: приветствие, питомцы, задачи на сегодня, быстрые действия.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @Binding var selectedTab: AppTab
    @State private var path: [AppRoute] = []
    @State private var showAddPetSheet = false
    @State private var showAddReminderSheet = false
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        todayTasksSection
                        upcomingSection
                        quickActionsSection
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .pets:
                    PetListViewModel()
                case .petDetail(let id):
                    PetDetailView(petId: id)
                case .health:
                    HealthView()
                case .feed:
                    FeedView()
                case .chat:
                    ChatView(onDismiss: { path.removeAll() })
                }
            }
            .onAppear {
                if app.pets.isEmpty {
                    Task { await app.loadAll() }
                }
            }
            .sheet(isPresented: $showAddPetSheet) {
                AddPetSheet(onSave: { pet in
                    Task { await app.addPet(pet) }
                    showAddPetSheet = false
                }, onCancel: { showAddPetSheet = false })
            }
            .sheet(isPresented: $showAddReminderSheet) {
                AddReminderSheet(
                    selectedPetId: app.pets.first?.id ?? "",
                    pets: app.pets,
                    onSave: { reminder in
                        Task { await app.addReminder(reminder) }
                        showAddReminderSheet = false
                    },
                    onCancel: { showAddReminderSheet = false }
                )
            }
        }
    }
    
    private var header: some View {
        VStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Добро пожаловать 👋")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Petio")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            myPetsSection
                .padding(.bottom, 8)
        }
        .background {
            PetCareTheme.primary
                .clipShape(
                    .rect(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 32,
                        bottomTrailingRadius: 32,
                        topTrailingRadius: 0
                    )
                )
                .ignoresSafeArea()
        }
    }
    
    private var myPetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetCareSectionHeader(
                title: "Мои питомцы",
                actionTitle: "Все",
                action: { path.append(.pets) },
                foregroundColor: .white
            )
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            
            if app.pets.isEmpty {
                Button {
                    showAddPetSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Добавить питомца")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(app.pets) { pet in
                            Button {
                                path.append(.petDetail(pet.id))
                            } label: {
                                HStack(spacing: 10) {
                                    AvatarView(url: pet.photo, placeholder: speciesEmoji(pet.species), size: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pet.name)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                        Text(pet.species)
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var todayTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PetCareSectionHeader(
                title: "Задачи на сегодня",
                actionTitle: "Все",
                action: { selectedTab = .health }
            )
            .padding(.horizontal, 20)
            
            let today = app.todayReminders()
            if today.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(PetCareTheme.primary.opacity(0.5))
                    Text("На сегодня задач нет!")
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.muted)
                    if !app.pets.isEmpty {
                        Button {
                            showAddReminderSheet = true
                        } label: {
                            Label("Добавить напоминание", systemImage: "plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(PetCareTheme.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(today) { r in
                        PetCareReminderRow(
                            title: r.title,
                            subtitle: "\(r.petName) · \(r.time)",
                            icon: r.type.sfSymbol,
                            iconColor: r.type.color,
                            completed: r.completed,
                            onToggle: { app.toggleReminder(id: r.id) }
                        )
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    private var upcomingSection: some View {
        Group {
            let upcoming = app.upcomingReminders()
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ближайшие")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PetCareTheme.primary)
                        .padding(.horizontal, 20)
                    VStack(spacing: 8) {
                        ForEach(upcoming) { r in
                            HStack(spacing: 12) {
                                IconBadge(icon: r.type.sfSymbol, color: r.type.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.title)
                                        .font(.system(size: 14))
                                        .foregroundColor(PetCareTheme.primary)
                                    Text("\(r.petName) · \(r.date)")
                                        .font(.system(size: 11))
                                        .foregroundColor(PetCareTheme.muted)
                                }
                                Spacer()
                                Text(r.time)
                                    .font(.system(size: 11))
                                    .foregroundColor(PetCareTheme.muted)
                            }
                            .padding(12)
                            .petCareCardStyle()
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 20)
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Быстрые действия")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(PetCareTheme.primary)
                .padding(.horizontal, 20)
            
            HStack(spacing: 12) {
                quickActionCard(title: "Советы AI", icon: "stethoscope", color: Color.green) {
                    path.append(.chat)
                }
                quickActionCard(title: "Лента", icon: "newspaper", color: Color.blue) {
                    path.append(.feed)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }
    
    private func quickActionCard(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(PetCareTheme.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .petCareCardStyle()
        }
        .buttonStyle(.plain)
    }
    
    private func speciesEmoji(_ species: String) -> String {
        switch species {
        case "Собака": return "🐕"
        case "Кошка": return "🐱"
        case "Птица": return "🦜"
        case "Кролик": return "🐰"
        default: return "🐾"
        }
    }
}

