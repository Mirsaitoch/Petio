//
//  PetAgeCalculator.swift
//  Petio
//
//  Вычисление возраста питомца по дате рождения.
//

import Foundation

enum PetAgeCalculator {
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Returns a human-readable age string like "2 года", "8 месяцев", "3 недели".
    static func computedAge(from birthDateString: String) -> String {
        guard !birthDateString.isEmpty,
              let birth = isoFormatter.date(from: birthDateString) else {
            return "Неизвестно"
        }
        let now = Date()
        guard birth <= now else { return "Неизвестно" }

        let cal = Calendar.current
        let years = cal.dateComponents([.year], from: birth, to: now).year ?? 0
        if years >= 1 {
            return "\(years) \(yearWord(years))"
        }
        let months = cal.dateComponents([.month], from: birth, to: now).month ?? 0
        if months >= 1 {
            return "\(months) \(monthWord(months))"
        }
        let weeks = cal.dateComponents([.weekOfYear], from: birth, to: now).weekOfYear ?? 0
        if weeks >= 1 {
            return "\(weeks) \(weekWord(weeks))"
        }
        return "Меньше недели"
    }

    private static func yearWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "лет" }
        switch mod10 {
        case 1: return "год"
        case 2, 3, 4: return "года"
        default: return "лет"
        }
    }

    private static func monthWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "месяцев" }
        switch mod10 {
        case 1: return "месяц"
        case 2, 3, 4: return "месяца"
        default: return "месяцев"
        }
    }

    private static func weekWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "недель" }
        switch mod10 {
        case 1: return "неделя"
        case 2, 3, 4: return "недели"
        default: return "недель"
        }
    }
}
