//
//  LocalStorage.swift
//  Petio
//
//  FileManager-based JSON persistence. Replaces UserDefaults for app data.
//  Files are stored in Application Support directory.
//

import Foundation

struct LocalStorage {

    // MARK: - Public API

    static func save<T: Encodable>(_ value: T, to file: StorageFile) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url(for: file), options: .atomic)
    }

    static func load<T: Decodable>(from file: StorageFile) -> T? {
        let fileURL = url(for: file)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL)
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func delete(file: StorageFile) {
        try? FileManager.default.removeItem(at: url(for: file))
    }

    // MARK: - Private

    private static let storageDirectory: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Petio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func url(for file: StorageFile) -> URL {
        storageDirectory.appendingPathComponent(file.filename)
    }
}
