import XCTest
@testable import Petio

class LocalStorageTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        StorageFile.allCases.forEach { LocalStorage.delete(file: $0) }
    }

    func testSaveAndLoadArray() {
        let pets: [Pet] = [
            Pet(id: "1", name: "Бобик", species: "Собака", breed: "Хаски", age: "2",
                weight: 20.0, photo: nil, birthDate: "2024-01-01",
                vaccinations: [], treatments: [], features: [])
        ]
        LocalStorage.save(pets, to: .pets)
        let loaded: [Pet]? = LocalStorage.load(from: .pets)
        XCTAssertEqual(loaded?.count, 1)
        XCTAssertEqual(loaded?.first?.name, "Бобик")
    }

    func testLoadReturnsNilWhenNoFile() {
        let loaded: [Pet]? = LocalStorage.load(from: .pets)
        XCTAssertNil(loaded)
    }

    func testDeleteRemovesFile() {
        let pets: [Pet] = [
            Pet(id: "1", name: "Бобик", species: "Собака", breed: "Хаски", age: "2",
                weight: 20.0, photo: nil, birthDate: "2024-01-01",
                vaccinations: [], treatments: [], features: [])
        ]
        LocalStorage.save(pets, to: .pets)
        LocalStorage.delete(file: .pets)
        let loaded: [Pet]? = LocalStorage.load(from: .pets)
        XCTAssertNil(loaded)
    }

    func testOverwriteUpdatesExistingFile() {
        let pets1: [Pet] = [
            Pet(id: "1", name: "Бобик", species: "Собака", breed: "Хаски", age: "2",
                weight: 20.0, photo: nil, birthDate: "2024-01-01",
                vaccinations: [], treatments: [], features: [])
        ]
        let pets2: [Pet] = []
        LocalStorage.save(pets1, to: .pets)
        LocalStorage.save(pets2, to: .pets)
        let loaded: [Pet]? = LocalStorage.load(from: .pets)
        XCTAssertEqual(loaded?.count, 0)
    }
}
