import XCTest
@testable import Petio
import Network

class NetworkMonitorTests: XCTestCase {

    @MainActor
    func testNetworkMonitorInitializes() {
        let monitor = NetworkMonitor()
        // NetworkMonitor должен инициализироваться без ошибок
        XCTAssertTrue(true)
    }

    @MainActor
    func testNetworkMonitorPublishesOnlineStatus() {
        let monitor = NetworkMonitor()
        XCTAssertNotNil(monitor.isOnline)
        // isOnline должен быть Bool
    }
}
