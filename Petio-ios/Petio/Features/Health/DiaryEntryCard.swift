//
//  DiaryEntryCard.swift
//  Petio
//
//  Карточка записи дневника здоровья с поддержкой свайпа для удаления.
//

import SwiftUI

struct DiaryEntryCard: View {
    let entry: HealthDiaryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var revealed = false

    private let deleteWidth: CGFloat = 72

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button behind the card
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    offset = 0
                    revealed = false
                }
                onDelete()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                    Text("Удалить")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.white)
                .frame(width: deleteWidth)
                .frame(maxHeight: .infinity)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            // Card content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.date)
                        .font(.system(size: 11))
                        .foregroundStyle(PetCareTheme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PetCareTheme.secondary)
                        .clipShape(Capsule())
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13))
                            .foregroundStyle(PetCareTheme.muted)
                    }
                    .buttonStyle(.plain)
                }
                Text(entry.note)
                    .font(.system(size: 14))
                    .foregroundStyle(PetCareTheme.primary)
                if !entry.tags.isEmpty {
                    FlowLayoutSimple(spacing: 6) {
                        ForEach(entry.tags) { tag in
                            Text(tag.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: tag.colorHex))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .petCareCardStyle()
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let tx = value.translation.width
                        if tx < 0 {
                            offset = max(tx + (revealed ? -deleteWidth : 0), -deleteWidth)
                        } else if revealed {
                            offset = min(tx - deleteWidth, 0)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if value.translation.width < -deleteWidth / 2 {
                                offset = -deleteWidth
                                revealed = true
                            } else {
                                offset = 0
                                revealed = false
                            }
                        }
                    }
            )
            .onTapGesture {
                if revealed {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        offset = 0
                        revealed = false
                    }
                }
            }
        }
    }
}
