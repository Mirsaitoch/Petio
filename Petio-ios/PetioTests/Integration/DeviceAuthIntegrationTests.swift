import XCTest
@testable import Petio

final class DeviceAuthIntegrationTests: XCTestCase {
    var authManager: AuthManager!
    var authViewModel: AuthViewModel!
    var deviceManager: DeviceManager!

    override func setUp() {
        super.setUp()
        authManager = AuthManager()
        authManager.deleteToken()
        authViewModel = AuthViewModel(authManager: authManager)
        deviceManager = DeviceManager.shared
    }

    override func tearDown() {
        super.tearDown()
        authManager.deleteToken()
        try? deviceManager.deleteDeviceID()
        authViewModel = nil
    }

    // MARK: - Device ID Persistence

    func testDeviceID_PersistsAcrossInstances() async throws {
        let firstID = try await deviceManager.getDeviceID()
        let secondID = try await deviceManager.getDeviceID()
        XCTAssertEqual(firstID, secondID, "Device ID should persist across calls")
    }

    // MARK: - Auth State Synchronization

    func testAuthViewModel_InitWithToken_SetsIsAuthenticated() {
        authManager.saveToken("test-token")
        let viewModel = AuthViewModel(authManager: authManager)
        XCTAssertTrue(viewModel.isAuthenticated)
    }

    func testAuthViewModel_DeleteToken_ClearsAuthentication() {
        authManager.saveToken("test-token")
        authManager.saveRefreshToken("refresh-token")

        authManager.deleteToken()

        XCTAssertNil(authManager.getToken())
        XCTAssertNil(authManager.getRefreshToken())
    }

    // MARK: - Token Storage Independence

    func testTokens_StoredIndependently() {
        let accessToken = "access-token-jwt"
        let refreshToken = "refresh-token-uuid"

        authManager.saveToken(accessToken)
        authManager.saveRefreshToken(refreshToken)

        XCTAssertEqual(authManager.getToken(), accessToken)
        XCTAssertEqual(authManager.getRefreshToken(), refreshToken)
    }

    func testTokenReplacement_UpdatesCorrectToken() {
        let oldAccessToken = "old-access"
        let oldRefreshToken = "old-refresh"

        authManager.saveToken(oldAccessToken)
        authManager.saveRefreshToken(oldRefreshToken)

        let newAccessToken = "new-access"
        authManager.saveToken(newAccessToken)

        XCTAssertEqual(authManager.getToken(), newAccessToken)
        XCTAssertEqual(authManager.getRefreshToken(), oldRefreshToken)
    }

    // MARK: - Account Info Model

    func testAccountInfo_CanBeDecodedFromJSON() throws {
        let json = """
        {
            "userId": "user-123",
            "email": "test@example.com",
            "isCurrentAccount": true
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let accountInfo = try JSONDecoder().decode(AccountInfo.self, from: data)

        XCTAssertEqual(accountInfo.userId, "user-123")
        XCTAssertEqual(accountInfo.email, "test@example.com")
        XCTAssertTrue(accountInfo.isCurrentAccount)
    }

    func testAccountInfo_WithNullEmail_DecodesSuccessfully() throws {
        let json = """
        {
            "userId": "user-456",
            "email": null,
            "isCurrentAccount": false
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let accountInfo = try JSONDecoder().decode(AccountInfo.self, from: data)

        XCTAssertEqual(accountInfo.userId, "user-456")
        XCTAssertNil(accountInfo.email)
        XCTAssertFalse(accountInfo.isCurrentAccount)
    }
}
