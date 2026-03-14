//
//  ChatView.swift
//  Petio
//
//  Чат с AI-помощником: быстрые вопросы, ввод, ответы.
//

import SwiftUI

struct ChatView: View {
    var onDismiss: (() -> Void)? = nil
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var authManager: AuthManager
    @State private var inputText = ""
    @State private var isTyping = false
    @FocusState private var inputFocused: Bool
    @State private var showAuthPrompt = false

    private let quickQuestions = [
        "Как часто кормить щенка?",
        "Признаки болезни у кошки",
        "Как приучить к лотку?",
        "Когда делать прививки?"
    ]

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            messagesList
            inputBar
        }
        .background(PetCareTheme.background)
        .sheet(isPresented: $showAuthPrompt) {
            AuthPromptSheet(
                isPresented: $showAuthPrompt,
                message: "Чтобы общаться с AI-помощником, войдите в аккаунт"
            )
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 12) {
            if let onDismiss {
                Button { onDismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            Text("AI-помощник")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
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
        .padding(.bottom, 10)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if app.chatMessages.isEmpty {
                        welcomeBlock(proxy: proxy)
                    }
                    ForEach(app.chatMessages) { msg in
                        MessageBubble(message: msg)
                    }
                    if isTyping {
                        TypingIndicator()
                    }
                    Color.clear
                        .frame(height: 8)
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: app.chatMessages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: isTyping) { _, v in
                if v { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
        }
    }

    private func welcomeBlock(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 48))
                .foregroundColor(PetCareTheme.primary)
                .frame(width: 80, height: 80)
                .background(PetCareTheme.secondary)
                .clipShape(Circle())
            Text("Привет! 👋")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(PetCareTheme.primary)
            Text("Я ваш AI-помощник по уходу за питомцами. Задайте любой вопрос!")
                .font(.system(size: 14))
                .foregroundColor(PetCareTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            VStack(spacing: 8) {
                ForEach(quickQuestions, id: \.self) { q in
                    Button {
                        sendMessage(q)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                                .foregroundColor(PetCareTheme.primary)
                            Text(q)
                                .font(.system(size: 14))
                                .foregroundColor(PetCareTheme.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(12)
                        .background(PetCareTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(PetCareTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 24)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Задайте вопрос...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PetCareTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(1...4)
                .focused($inputFocused)
                .onSubmit { sendMessage(inputText) }
            Button {
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? PetCareTheme.muted : PetCareTheme.primary)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PetCareTheme.cardBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(PetCareTheme.border),
            alignment: .top
        )
    }

    private func sendMessage(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        guard authManager.isAuthenticated else {
            showAuthPrompt = true
            return
        }
        inputText = ""
        isTyping = true
        Task {
            await app.sendChatMessage(t)
            isTyping = false
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: 60) }
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(PetCareTheme.primary)
                        Text("AI-помощник")
                            .font(.system(size: 11))
                            .foregroundColor(PetCareTheme.primary)
                    }
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundColor(PetCareTheme.primary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PetCareTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(PetCareTheme.border, lineWidth: 1)
                )
                Spacer(minLength: 60)
            }
            if message.role == .user {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(14)
                    .background(PetCareTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

struct TypingIndicator: View {
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(PetCareTheme.primary)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(14)
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(PetCareTheme.border, lineWidth: 1))
            Spacer()
        }
    }
}
