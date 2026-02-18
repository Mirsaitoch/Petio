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
    case health
    case feed
    case chat
}
