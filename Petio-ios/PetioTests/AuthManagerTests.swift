import XCTest
@testable import Petio

final class AuthManagerTests: XCTestCase {
    var sut: AuthManager!

    override func setUp() {
        super.setUp()
        sut = AuthManager()
        // Очистить Keychain перед каждым тестом
        sut.deleteToken()
    }

    // MARK: - Token Tests

    func testSaveToken_StoresTokenInKeychain() {
        let testToken = "test.jwt.token"

        sut.saveToken(testToken)
        let retrieved = sut.getToken()

        XCTAssertEqual(retrieved, testToken)
    }

    func testGetToken_ReturnsNilWhenNoTokenSaved() {
        let retrieved = sut.getToken()
        XCTAssertNil(retrieved)
    }

    func testDeleteToken_RemovesToken() {
        sut.saveToken("test.jwt.token")
        sut.deleteToken()
        let retrieved = sut.getToken()
        XCTAssertNil(retrieved)
    }

    // MARK: - RefreshToken Tests

    func testSaveRefreshToken_StoresRefreshTokenInKeychain() {
        let testRefreshToken = "refresh-token-uuid-123"

        sut.saveRefreshToken(testRefreshToken)
        let retrieved = sut.getRefreshToken()

        XCTAssertEqual(retrieved, testRefreshToken)
    }

    func testGetRefreshToken_ReturnsNilWhenNoRefreshTokenSaved() {
        let retrieved = sut.getRefreshToken()
        XCTAssertNil(retrieved)
    }

    func testSaveRefreshToken_OverwritesPreviousValue() {
        let firstToken = "refresh-token-1"
        let secondToken = "refresh-token-2"

        sut.saveRefreshToken(firstToken)
        sut.saveRefreshToken(secondToken)
        let retrieved = sut.getRefreshToken()

        XCTAssertEqual(retrieved, secondToken)
    }

    // MARK: - DeleteToken Tests

    func testDeleteToken_RemovesBothTokenAndRefreshToken() {
        let token = "test.jwt.token"
        let refreshToken = "refresh-token-uuid"

        sut.saveToken(token)
        sut.saveRefreshToken(refreshToken)

        sut.deleteToken()

        let retrievedToken = sut.getToken()
        let retrievedRefreshToken = sut.getRefreshToken()

        XCTAssertNil(retrievedToken)
        XCTAssertNil(retrievedRefreshToken)
    }

    // MARK: - Integration Tests

    func testAuthManager_SaveAndRetrieveBothTokens() {
        let token = "access.token.jwt"
        let refreshToken = "refresh-token-uuid-456"

        sut.saveToken(token)
        sut.saveRefreshToken(refreshToken)

        let retrievedToken = sut.getToken()
        let retrievedRefreshToken = sut.getRefreshToken()

        XCTAssertEqual(retrievedToken, token)
        XCTAssertEqual(retrievedRefreshToken, refreshToken)
    }

    func testAuthManager_IndependentTokenStorage() {
        let token = "access.token"
        let refreshToken = "refresh.token"

        sut.saveToken(token)
        sut.saveRefreshToken(refreshToken)

        sut.deleteToken()

        XCTAssertNil(sut.getToken())
        XCTAssertNil(sut.getRefreshToken())
    }

    // MARK: - Critical Tests for Keychain Save/Update

    func testSaveToken_UpdatesExistingToken() {
        let firstToken = "first.jwt.token"
        let secondToken = "second.jwt.token"

        // Сохранить первый токен
        sut.saveToken(firstToken)
        var retrieved = sut.getToken()
        XCTAssertEqual(retrieved, firstToken)

        // Перезаписать вторым токеном (КРИТИЧНО - эту ошибку мы исправили)
        sut.saveToken(secondToken)
        retrieved = sut.getToken()

        // Должен быть второй токен, а не ошибка Keychain
        XCTAssertEqual(retrieved, secondToken)
    }

    func testSaveToken_IsAuthenticatedAfterSave() {
        let testToken = "test.jwt.token"

        sut.saveToken(testToken)

        // После сохранения токена, должны быть аутентифицированы
        XCTAssertTrue(sut.isAuthenticated)
    }

    func testSaveRefreshToken_CanUpdateMultipleTimes() {
        let token1 = "refresh-1"
        let token2 = "refresh-2"
        let token3 = "refresh-3"

        // Сохранить и обновить несколько раз
        sut.saveRefreshToken(token1)
        XCTAssertEqual(sut.getRefreshToken(), token1)

        sut.saveRefreshToken(token2)
        XCTAssertEqual(sut.getRefreshToken(), token2)

        sut.saveRefreshToken(token3)
        XCTAssertEqual(sut.getRefreshToken(), token3)
    }
}
