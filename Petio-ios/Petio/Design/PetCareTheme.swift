//
//  PetCareTheme.swift
//  Petio
//
//  Цвета и типографика дизайн-системы Pet Care.
//

import SwiftUI

enum PetCareTheme {
    static let primary = Color(red: 27/255, green: 94/255, blue: 59/255)
    static let primaryForeground = Color.white
    static let background = Color(red: 240/255, green: 244/255, blue: 241/255)
    static let cardBackground = Color.white
    static let border = Color(red: 229/255, green: 231/255, blue: 235/255)
    static let muted = Color(red: 107/255, green: 114/255, blue: 128/255)
    static let secondary = Color(red: 243/255, green: 244/255, blue: 246/255)
    static let inputBackground = Color(red: 249/255, green: 250/255, blue: 251/255)

    static let reminderFeeding = Color.orange
    static let reminderVaccination = Color.blue
    static let reminderDeworming = Color.purple
    static let reminderGrooming = Color.pink
}

extension View {
    func petCareCardStyle() -> some View {
        self
            .background(PetCareTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(PetCareTheme.border, lineWidth: 1))
    }
}
