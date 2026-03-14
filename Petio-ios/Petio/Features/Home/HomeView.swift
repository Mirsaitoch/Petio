//
//  HomeView.swift
//  Petio
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @Binding var selectedTab: AppTab
    @State private var path: [AppRoute] = []
    @State private var showAddPetSheet = false
    @State private var showAddReminderSheet = false
    @State private var showAddDiarySheet = false
    @State private var quickTaskText = ""
    @FocusState private var quickTaskFocused: Bool
    
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
            .background(PetCareTheme.background)
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
                case .shelters:
                    SheltersListView()
                case .shelterDetail(let shelter):
                    ShelterDetailView(shelter: shelter)
                }
            }
            .onAppear {
                if app.pets.isEmpty || app.reminders.isEmpty {
                    Task { await app.loadAll() }
                }
            }
            .sheet(isPresented: $showAddPetSheet) {
                AddPetSheet(onSave: { pet in
                    Task { await app.addPet(pet) }
                    showAddPetSheet = false
                }, onCancel: { showAddPetSheet = false })
            }
            .sheet(isPresented: $showAddDiarySheet) {
                let petId = app.selectedPetId.isEmpty ? (app.pets.first?.id ?? "") : app.selectedPetId
                AddDiarySheet(petId: petId, pets: app.pets) { entry in
                    Task { await app.addDiaryEntry(entry) }
                    showAddDiarySheet = false
                } onCancel: { showAddDiarySheet = false }
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
                Text("Petio")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            myPetsSection
                .padding(.bottom, 8)
        }
        .frame(minHeight: 130, alignment: .top)
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
                                    AvatarView(url: pet.photo, imageName: speciesImageName(pet.species), size: 44)
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

            if !app.pets.isEmpty {
                quickTaskInput
                    .padding(.horizontal, 20)
            }

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
                        Button { app.toggleReminder(id: r.id) } label: {
                            PetCareCard {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .stroke(PetCareTheme.primary.opacity(0.3), lineWidth: 2)
                                            .frame(width: 26, height: 26)
                                        if r.completed {
                                            Circle().fill(PetCareTheme.primary).frame(width: 26, height: 26)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.title)
                                            .font(.system(size: 14))
                                            .strikethrough(r.completed)
                                            .foregroundColor(r.completed ? PetCareTheme.muted : PetCareTheme.primary)
                                        Text("\(r.petName) · \(r.time)")
                                            .font(.system(size: 11))
                                            .foregroundColor(PetCareTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: r.type.sfSymbol)
                                        .font(.system(size: 15))
                                        .foregroundColor(r.type.color)
                                        .frame(width: 30, height: 30)
                                        .background(r.type.color.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .opacity(r.completed ? 0.7 : 1)
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
                            PetCareCard {
                                HStack(spacing: 12) {
                                    Image(systemName: r.type.sfSymbol)
                                        .font(.system(size: 15))
                                        .foregroundColor(r.type.color)
                                        .frame(width: 30, height: 30)
                                        .background(r.type.color.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(PetCareTheme.muted)
                                }
                            }
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

            if !app.pets.isEmpty {
                Button {
                    showAddDiarySheet = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#9C27B0"))
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "#9C27B0").opacity(0.13))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Запись в дневник")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(PetCareTheme.primary)
                        }
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(PetCareTheme.muted)
                    }
                    .padding(14)
                    .petCareCardStyle()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }

            Button {
                path.append(.shelters)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                        .frame(width: 40, height: 40)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Фонды и приюты")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(PetCareTheme.primary)
                        Text("6 организаций")
                            .font(.system(size: 11))
                            .foregroundColor(PetCareTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PetCareTheme.muted)
                }
                .padding(14)
                .petCareCardStyle()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }
    
    private func quickActionCard(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PetCareCard {
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
            }
        }
        .buttonStyle(.plain)
    }
    
    private var quickTaskInput: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(quickTaskText.isEmpty ? PetCareTheme.muted : PetCareTheme.primary)
                .animation(.easeInOut(duration: 0.15), value: quickTaskText.isEmpty)

            TextField("Быстрая задача...", text: $quickTaskText)
                .font(.system(size: 14))
                .foregroundColor(PetCareTheme.primary)
                .focused($quickTaskFocused)
                .submitLabel(.done)
                .onSubmit { submitQuickTask() }

            if !quickTaskText.isEmpty {
                Button(action: submitQuickTask) {
                    Text("Добавить")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(PetCareTheme.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PetCareTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    quickTaskFocused ? PetCareTheme.primary.opacity(0.5) : PetCareTheme.border,
                    lineWidth: quickTaskFocused ? 1.5 : 1
                )
        )
        .animation(.easeInOut(duration: 0.15), value: quickTaskFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: quickTaskText.isEmpty)
    }

    private func submitQuickTask() {
        let trimmed = quickTaskText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let petId = app.selectedPetId.isEmpty ? (app.pets.first?.id ?? "") : app.selectedPetId
        let petName = app.pets.first(where: { $0.id == petId })?.name ?? ""
        let now = Date()
        let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"
        let reminder = Reminder(
            id: UUID().uuidString,
            petId: petId,
            petName: petName,
            type: .other,
            customTypeName: nil,
            title: trimmed,
            date: dateFmt.string(from: now),
            time: timeFmt.string(from: now),
            completed: false
        )
        Task { await app.addReminder(reminder) }
        quickTaskText = ""
        quickTaskFocused = false
    }

}


