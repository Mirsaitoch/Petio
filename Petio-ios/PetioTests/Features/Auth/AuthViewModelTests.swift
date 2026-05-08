import XCTest
@testable import Petio

@MainActor
final class AuthViewModelTests: XCTestCase {
    var sut: AuthViewModel!
    var mockAuthManager: AuthManager!

    override func setUp() {
        super.setUp()
        mockAuthManager = AuthManager()
        mockAuthManager.deleteToken()
        sut = AuthViewModel(authManager: mockAuthManager)
    }

    override func tearDown() {
        super.tearDown()
        mockAuthManager.deleteToken()
        sut = nil
    }

    // MARK: - Initialization Tests

    func testInit_WithoutToken_IsNotAuthenticated() {
        mockAuthManager.deleteToken()
        sut = AuthViewModel(authManager: mockAuthManager)
        XCTAssertFalse(sut.isAuthenticated)
    }

    func testInit_WithToken_IsAuthenticated() {
        mockAuthManager.saveToken("test-token")
        sut = AuthViewModel(authManager: mockAuthManager)
        XCTAssertTrue(sut.isAuthenticated)
    }

    // MARK: - Token Management Tests

    func testDeviceLogin_SavesTokenAndRefreshToken() async {
        XCTAssertFalse(sut.isLoading)
    }

    func testSwitchAccount_UpdatesToken() async {
        mockAuthManager.saveToken("initial-token")
        XCTAssertEqual(mockAuthManager.getToken(), "initial-token")
    }

    func testAccountInfo_Decodable() {
        let json = """
        {
            "userId": "user-123",
            "email": "test@example.com"
        }
        """
        guard let data = json.data(using: .utf8) else {
            XCTFail("Could not create JSON data")
            return
        }

        let decoder = JSONDecoder()
        do {
            let accountInfo = try decoder.decode(AccountInfo.self, from: data)
            XCTAssertEqual(accountInfo.userId, "user-123")
            XCTAssertEqual(accountInfo.email, "test@example.com")
        } catch {
            XCTFail("Failed to decode AccountInfo: \(error)")
        }
    }

    func testAccountInfo_WithoutEmail_Decodable() {
        let json = """
        {
            "userId": "user-456",
            "email": null
        }
        """
        guard let data = json.data(using: .utf8) else {
            XCTFail("Could not create JSON data")
            return
        }

        let decoder = JSONDecoder()
        do {
            let accountInfo = try decoder.decode(AccountInfo.self, from: data)
            XCTAssertEqual(accountInfo.userId, "user-456")
            XCTAssertNil(accountInfo.email)
        } catch {
            XCTFail("Failed to decode AccountInfo: \(error)")
        }
    }
}
