//
//  AppRoute.swift
//  Petio
//
//  Маршруты для навигации.
//

import Foundation

enum AppRoute: Hashable {
    case pets
    case petDetail(String)
    case petReminders(String)
    case petWeight(String)
    case petDiary(String)
    case feed
    case chat
    case shelters
    case shelterDetail(Shelter)
}
