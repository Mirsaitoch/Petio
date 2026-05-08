import XCTest
@testable import Petio

final class HTTPAPIClientTests: XCTestCase {
    var sut: HTTPAPIClient!
    var mockAuthManager: AuthManager!

    override func setUp() {
        super.setUp()
        mockAuthManager = AuthManager()
        mockAuthManager.deleteToken()
        sut = HTTPAPIClient(authManager: mockAuthManager, baseURL: "http://test.local/v1")
    }

    override func tearDown() {
        super.tearDown()
        mockAuthManager.deleteToken()
        sut = nil
    }

    // MARK: - Token Storage Tests

    func testAuthManager_SavesAndRetrievesAccessToken() {
        let token = "test-access-token-jwt"
        mockAuthManager.saveToken(token)
        XCTAssertEqual(mockAuthManager.getToken(), token)
    }

    func testAuthManager_SavesAndRetrievesRefreshToken() {
        let refreshToken = "test-refresh-token-uuid"
        mockAuthManager.saveRefreshToken(refreshToken)
        XCTAssertEqual(mockAuthManager.getRefreshToken(), refreshToken)
    }

    func testAuthManager_SavesAccessAndRefreshTokensIndependently() {
        let accessToken = "access-token"
        let refreshToken = "refresh-token"

        mockAuthManager.saveToken(accessToken)
        mockAuthManager.saveRefreshToken(refreshToken)

        XCTAssertEqual(mockAuthManager.getToken(), accessToken)
        XCTAssertEqual(mockAuthManager.getRefreshToken(), refreshToken)
    }

    func testAuthManager_DeletesRemovesBothTokens() {
        mockAuthManager.saveToken("access-token")
        mockAuthManager.saveRefreshToken("refresh-token")

        mockAuthManager.deleteToken()

        XCTAssertNil(mockAuthManager.getToken())
        XCTAssertNil(mockAuthManager.getRefreshToken())
    }
}
