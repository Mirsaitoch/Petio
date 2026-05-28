//
//  SwipeReminderCard.swift
//  Petio
//
//  Карточка напоминания с поддержкой свайпа: влево — удалить, вправо — редактировать.
//

import SwiftUI

struct SwipeReminderCard: View {
    let reminder: Reminder
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var revealed: Revealed = .none

    private enum Revealed { case none, edit, delete }
    private let actionWidth: CGFloat = 72

    var body: some View {
        ZStack {
            // Edit button (left, revealed by swipe right)
            HStack(spacing: 0) {
                Button {
                    snap(to: .none)
                    onEdit()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                        Text("Изменить")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(PetCareTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                Spacer()
            }

            // Delete button (right, revealed by swipe left)
            HStack(spacing: 0) {
                Spacer()
                Button {
                    snap(to: .none)
                    onDelete()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                        Text("Удалить")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }

            // Row content
            PetCareReminderRow(
                title: reminder.title,
                subtitle: "\(reminder.date) · \(reminder.time)",
                icon: reminder.type.sfSymbol,
                iconColor: reminder.type.color,
                completed: reminder.completed,
                onToggle: onToggle
            )
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let base: CGFloat
                        switch revealed {
                        case .none:   base = 0
                        case .edit:   base = actionWidth
                        case .delete: base = -actionWidth
                        }
                        let raw = base + value.translation.width
                        offset = min(max(raw, -actionWidth), actionWidth)
                    }
                    .onEnded { value in
                        let total = value.translation.width
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if total > actionWidth / 2 {
                                offset = actionWidth; revealed = .edit
                            } else if total < -actionWidth / 2 {
                                offset = -actionWidth; revealed = .delete
                            } else {
                                offset = 0; revealed = .none
                            }
                        }
                    }
            )
            .onTapGesture {
                if revealed != .none { snap(to: .none) }
            }
        }
    }

    private func snap(to state: Revealed) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            revealed = state
            switch state {
            case .none:   offset = 0
            case .edit:   offset = actionWidth
            case .delete: offset = -actionWidth
            }
        }
    }
}
