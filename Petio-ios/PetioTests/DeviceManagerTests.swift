import XCTest
@testable import Petio

final class DeviceManagerTests: XCTestCase {
    var sut: DeviceManager!

    override func setUp() {
        super.setUp()
        sut = DeviceManager()
        // Очистить Keychain перед каждым тестом
        try? sut.deleteDeviceID()
    }

    func testGetDeviceID_CreatesNewUUIDOnFirstCall() async throws {
        let firstCall = try await sut.getDeviceID()
        XCTAssertFalse(firstCall.isEmpty)
        XCTAssertEqual(firstCall.count, 36) // UUID формат: 8-4-4-4-12
    }

    func testGetDeviceID_ReturnsSameIDOnSecondCall() async throws {
        let firstID = try await sut.getDeviceID()
        let secondID = try await sut.getDeviceID()
        XCTAssertEqual(firstID, secondID)
    }
}
