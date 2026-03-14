//
//  StorageFile.swift
//  Petio
//
//  Enum of all local JSON storage files.
//

import Foundation

enum StorageFile: String, CaseIterable {
    case pets
    case reminders
    case diary
    case weight
    case tags
    case profile

    var filename: String { "\(rawValue).json" }
}
