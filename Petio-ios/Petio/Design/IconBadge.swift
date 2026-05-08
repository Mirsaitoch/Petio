//
//  IconBadge.swift
//  Petio
//
//  Иконка в цветном бейдже (тип напоминания и т.д.).
//

import SwiftUI

struct IconBadge: View {
    let icon: String
    let color: Color
    let size: CGFloat

    init(icon: String, color: Color, size: CGFloat = 32) {
        self.icon = icon
        self.color = color
        self.size = size
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.5))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

extension ReminderType {
    var sfSymbol: String {
        switch self {
        case .feeding: return "fork.knife"
        case .vaccination: return "syringe"
        case .deworming: return "ant"
        case .grooming: return "scissors"
        }
    }

    var color: Color {
        switch self {
        case .feeding: return PetCareTheme.reminderFeeding
        case .vaccination: return PetCareTheme.reminderVaccination
        case .deworming: return PetCareTheme.reminderDeworming
        case .grooming: return PetCareTheme.reminderGrooming
        }
    }
}
