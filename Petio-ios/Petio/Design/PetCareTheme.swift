//
//  PetCareTheme.swift
//  Petio
//
//  Цвета и типографика дизайн-системы Pet Care.
//  Цвета заданы в Colors.xcassets.
//

import SwiftUI

enum PetCareTheme {
    static let primary = Color("Primary")
    static let primaryForeground = Color("PrimaryForeground")
    static let background = Color("Background")
    static let cardBackground = Color("CardBackground")
    static let border = Color("Border")
    static let muted = Color("Muted")
    static let secondary = Color("Secondary")
    static let inputBackground = Color("InputBackground")

    static let reminderFeeding = Color("ReminderFeeding")
    static let reminderVaccination = Color("ReminderVaccination")
    static let reminderDeworming = Color("ReminderDeworming")
    static let reminderGrooming = Color("ReminderGrooming")
}

extension View {
    func petCareCardStyle() -> some View {
        self
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(PetCareTheme.border, lineWidth: 1))
    }
}
