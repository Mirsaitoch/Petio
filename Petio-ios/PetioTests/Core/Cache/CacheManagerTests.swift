import XCTest
@testable import Petio

class CacheManagerTests: XCTestCase {
    var cache: CacheManager!

    override func setUp() {
        super.setUp()
        cache = CacheManager()
        cache.clearAll() // Очистить перед каждым тестом
    }

    func testSaveAndLoadPets() {
        let pets = [
            Pet(
                id: "1",
                name: "Тор",
                species: "собака",
                breed: "хаски",
                age: "3",
                weight: 30.0,
                photo: nil,
                birthDate: "2023-01-01",
                vaccinations: [],
                treatments: [],
                features: []
            )
        ]

        cache.savePets(pets)
        let loaded = cache.loadPets()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Тор")
    }

    func testLoadEmptyPets() {
        let loaded = cache.loadPets()
        XCTAssertEqual(loaded.count, 0)
    }

    func testSaveAndLoadReminders() {
        let reminders = [
            Reminder(id: "1", petId: "pet1", petName: "Тор", type: .feeding, title: "Кормление", date: "2026-03-07", time: "09:00", completed: false)
        ]

        cache.saveReminders(reminders)
        let loaded = cache.loadReminders()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "Кормление")
    }

    func testSaveAndLoadDiaryEntries() {
        let entries = [
            HealthDiaryEntry(id: "1", petId: "pet1", date: "2026-03-07", note: "Хорошо себя чувствует", tags: [])
        ]

        cache.saveDiaryEntries(entries)
        let loaded = cache.loadDiaryEntries()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.note, "Хорошо себя чувствует")
    }

    func testClearAllRemovesAllData() {
        let pets = [Pet(id: "1", name: "Тор", species: "собака", breed: "хаски", age: "3", weight: 30.0, photo: nil, birthDate: "2023-01-01", vaccinations: [], treatments: [], features: [])]
        cache.savePets(pets)

        cache.clearAll()

        XCTAssertEqual(cache.loadPets().count, 0)
    }
}
