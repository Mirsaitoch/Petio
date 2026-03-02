//
//  DiaryTagDefaults.swift
//  Petio
//
//  7 стандартных тегов дневника и вспомогательный инициализатор Color из hex.
//

import SwiftUI

extension DiaryTag {
    static let defaults: [DiaryTag] = [
        DiaryTag(id: "default_vet",      name: "Визит к ветеринару", colorHex: "#2196F3", isDefault: true),
        DiaryTag(id: "default_vaccine",  name: "Прививка",            colorHex: "#4CAF50", isDefault: true),
        DiaryTag(id: "default_illness",  name: "Болезнь",             colorHex: "#F44336", isDefault: true),
        DiaryTag(id: "default_mood",     name: "Хорошее настроение",  colorHex: "#FFC107", isDefault: true),
        DiaryTag(id: "default_appetite", name: "Плохой аппетит",      colorHex: "#FF9800", isDefault: true),
        DiaryTag(id: "default_activity", name: "Активность",          colorHex: "#00BCD4", isDefault: true),
        DiaryTag(id: "default_grooming", name: "Груминг",             colorHex: "#9C27B0", isDefault: true),
    ]
}

extension Color {
    /// Creates a Color from a CSS hex string like "#FF5733" or "FF5733".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }

    /// Returns a CSS hex string like "#FF5733".
    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
