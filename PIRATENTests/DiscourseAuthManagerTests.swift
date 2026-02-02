//
//  DiscourseAuthManagerTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 01.02.26.
//

import XCTest
@testable import PIRATEN

final class DiscourseAuthManagerTests: XCTestCase {

    // MARK: - Properties

    var sut: DiscourseAuthManager!
    var rsaKeyManager: RSAKeyManager!

    // MARK: - Test Configuration
    // These match the values in Debug.xcconfig for consistent test behavior

    static let testBaseURL = "https://diskussion.piratenpartei.de"
    static let testClientID = "de.meine-piraten.ios-app"
    static let testRedirectScheme = "piratenapp"
    static let testRedirectHost = "discourse_auth"
    static let testAppName = "PIRATEN iOS App"

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        rsaKeyManager = RSAKeyManager()

        // Clean up any existing keys before each test
        try? rsaKeyManager.deleteKeyPair()
    }

    override func tearDown() {
        // Clean up keys after tests
        try? rsaKeyManager.deleteKeyPair()
        sut = nil
        rsaKeyManager = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Creates a DiscourseAuthManager with test configuration
    private func makeTestableAuthManager() -> DiscourseAuthManager {
        return DiscourseAuthManager(
            baseURL: Self.testBaseURL,
            clientID: Self.testClientID,
            redirectScheme: Self.testRedirectScheme,
            redirectHost: Self.testRedirectHost,
            applicationName: Self.testAppName,
            rsaKeyManager: rsaKeyManager
        )
    }

    // MARK: - Auth URL Building Tests
    // Note: Simple init test removed - the testBuildAuthURL tests implicitly verify
    // initialization works, and we avoid keychain-related test environment issues

    func testBuildAuthURL_ContainsRequiredParameters() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = makeTestableAuthManager()

        // When: Building auth URL
        let url = try sut.buildAuthURL()

        // Then: URL should contain all required parameters
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertNotNil(components)

        let queryItems = components?.queryItems ?? []
        let queryDict = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })

        // Verify all required parameters are present
        XCTAssertNotNil(queryDict["client_id"], "client_id parameter is required")
        XCTAssertNotNil(queryDict["nonce"], "nonce parameter is required")
        XCTAssertNotNil(queryDict["auth_redirect"], "auth_redirect parameter is required")
        XCTAssertNotNil(queryDict["application_name"], "application_name parameter is required")
        XCTAssertNotNil(queryDict["public_key"], "public_key parameter is required")
        XCTAssertNotNil(queryDict["scopes"], "scopes parameter is required")
    }

    func testBuildAuthURL_HasCorrectEndpoint() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = makeTestableAuthManager()

        // When: Building auth URL
        let url = try sut.buildAuthURL()

        // Then: URL should point to /user-api-key/new endpoint
        XCTAssertTrue(url.path.hasSuffix("/user-api-key/new"))
    }

    func testBuildAuthURL_NonceIsHexEncoded64Chars() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = makeTestableAuthManager()

        // When: Building auth URL
        let url = try sut.buildAuthURL()

        // Then: Nonce should be 64 hex characters (32 bytes)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let nonce = queryItems.first(where: { $0.name == "nonce" })?.value

        XCTAssertNotNil(nonce)
        XCTAssertEqual(nonce?.count, 64, "Nonce should be 32 bytes = 64 hex characters")
        XCTAssertTrue(nonce?.allSatisfy { $0.isHexDigit } ?? false, "Nonce should only contain hex characters")
    }

    func testBuildAuthURL_PublicKeyIsPEMFormat() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = makeTestableAuthManager()

        // When: Building auth URL
        let url = try sut.buildAuthURL()

        // Then: Public key should be in PEM format
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let publicKey = queryItems.first(where: { $0.name == "public_key" })?.value

        XCTAssertNotNil(publicKey)
        XCTAssertTrue(publicKey?.contains("-----BEGIN PUBLIC KEY-----") ?? false)
        XCTAssertTrue(publicKey?.contains("-----END PUBLIC KEY-----") ?? false)
    }

    func testBuildAuthURL_ScopesIncludeReadWriteSessionInfo() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = makeTestableAuthManager()

        // When: Building auth URL
        let url = try sut.buildAuthURL()

        // Then: Scopes should include read, write (for M4 messaging), and session_info
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let scopes = queryItems.first(where: { $0.name == "scopes" })?.value

        XCTAssertNotNil(scopes)
        XCTAssertTrue(scopes?.contains("read") ?? false, "Should include read scope")
        XCTAssertTrue(scopes?.contains("write") ?? false, "Should include write scope for M4 messaging")
        XCTAssertTrue(scopes?.contains("session_info") ?? false, "Should include session_info scope")
    }

    func testBuildAuthURL_AuthRedirectUsesCustomScheme() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = makeTestableAuthManager()

        // When: Building auth URL
        let url = try sut.buildAuthURL()

        // Then: auth_redirect should use the custom URL scheme from config
        // Config: DISCOURSE_AUTH_REDIRECT_SCHEME=piratenapp, DISCOURSE_AUTH_REDIRECT_HOST=discourse_auth
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let authRedirect = queryItems.first(where: { $0.name == "auth_redirect" })?.value

        XCTAssertNotNil(authRedirect)
        XCTAssertTrue(authRedirect?.hasPrefix("piratenapp://") ?? false, "Should use configured scheme")
        XCTAssertTrue(authRedirect?.contains("discourse_auth") ?? false, "Should use configured host")
    }

    func testBuildAuthURL_StoresNonce() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = makeTestableAuthManager()

        // When: Building auth URL
        let url = try sut.buildAuthURL()

        // Then: Nonce should be stored for later verification
        XCTAssertNotNil(sut.currentNonce)
        XCTAssertEqual(sut.currentNonce?.count, 64)

        // And it should match the nonce in the URL
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let urlNonce = queryItems.first(where: { $0.name == "nonce" })?.value

        XCTAssertEqual(sut.currentNonce, urlNonce)
    }

    func testBuildAuthURL_GeneratesUniqueNonceEachTime() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = makeTestableAuthManager()

        // When: Building auth URL twice
        _ = try sut.buildAuthURL()
        let firstNonce = sut.currentNonce

        _ = try sut.buildAuthURL()
        let secondNonce = sut.currentNonce

        // Then: Each call should generate a different nonce
        XCTAssertNotEqual(firstNonce, secondNonce)
    }

    func testBuildAuthURL_ReusesExistingRSAKeyPair() throws {
        // Given: An RSA key pair already exists
        sut = makeTestableAuthManager()
        _ = try sut.buildAuthURL()
        let firstURL = try sut.buildAuthURL()

        // When: Building auth URL again
        let secondURL = try sut.buildAuthURL()

        // Then: Both URLs should use the same public key
        let firstComponents = URLComponents(url: firstURL, resolvingAgainstBaseURL: false)
        let firstPublicKey = firstComponents?.queryItems?.first(where: { $0.name == "public_key" })?.value

        let secondComponents = URLComponents(url: secondURL, resolvingAgainstBaseURL: false)
        let secondPublicKey = secondComponents?.queryItems?.first(where: { $0.name == "public_key" })?.value

        XCTAssertEqual(firstPublicKey, secondPublicKey, "Should reuse the same RSA key pair")
    }

    // MARK: - Nonce Verification Tests

    func testVerifyNonce_WithMatchingNonce_ReturnsTrue() throws {
        // Given: A nonce was generated during auth URL building
        sut = makeTestableAuthManager()
        _ = try sut.buildAuthURL()
        let expectedNonce = sut.currentNonce!

        // When: Verifying with the same nonce
        let result = sut.verifyNonce(expectedNonce)

        // Then: Verification should succeed
        XCTAssertTrue(result)
    }

    func testVerifyNonce_WithDifferentNonce_ReturnsFalse() throws {
        // Given: A nonce was generated during auth URL building
        sut = makeTestableAuthManager()
        _ = try sut.buildAuthURL()

        // When: Verifying with a different nonce
        let result = sut.verifyNonce("0000000000000000000000000000000000000000000000000000000000000000")

        // Then: Verification should fail
        XCTAssertFalse(result)
    }

    func testVerifyNonce_WithNoStoredNonce_ReturnsFalse() throws {
        // Given: No nonce has been generated yet
        sut = makeTestableAuthManager()

        // When: Attempting to verify a nonce
        let result = sut.verifyNonce("0000000000000000000000000000000000000000000000000000000000000000")

        // Then: Verification should fail
        XCTAssertFalse(result)
    }

    func testClearNonce_RemovesStoredNonce() throws {
        // Given: A nonce was generated during auth URL building
        sut = makeTestableAuthManager()
        _ = try sut.buildAuthURL()
        XCTAssertNotNil(sut.currentNonce)

        // When: Clearing the nonce
        sut.clearNonce()

        // Then: Nonce should be nil
        XCTAssertNil(sut.currentNonce)
    }

    // MARK: - Callback URL Parsing Tests

    func testParseCallbackURL_WithPayloadQueryParameter_ExtractsPayload() throws {
        // Given: A callback URL with payload as query parameter
        sut = makeTestableAuthManager()
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth?payload=encryptedBase64Data123")!

        // When: Parsing the callback URL
        let result = try sut.parseCallbackURL(callbackURL)

        // Then: Should extract the payload
        XCTAssertEqual(result.encryptedPayload, "encryptedBase64Data123")
    }

    func testParseCallbackURL_WithPayloadInFragment_ExtractsPayload() throws {
        // Given: A callback URL with payload in fragment
        sut = makeTestableAuthManager()
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth#payload=encryptedBase64Data456")!

        // When: Parsing the callback URL
        let result = try sut.parseCallbackURL(callbackURL)

        // Then: Should extract the payload from fragment
        XCTAssertEqual(result.encryptedPayload, "encryptedBase64Data456")
    }

    func testParseCallbackURL_WithRawFragmentPayload_ExtractsPayload() throws {
        // Given: A callback URL with raw payload in fragment (no key=value)
        sut = makeTestableAuthManager()
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth#rawEncryptedPayload789")!

        // When: Parsing the callback URL
        let result = try sut.parseCallbackURL(callbackURL)

        // Then: Should extract the raw fragment as payload
        XCTAssertEqual(result.encryptedPayload, "rawEncryptedPayload789")
    }

    func testParseCallbackURL_WithURLEncodedPayload_DecodesPayload() throws {
        // Given: A callback URL with URL-encoded payload
        sut = makeTestableAuthManager()
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth?payload=hello%20world%2B%3D")!

        // When: Parsing the callback URL
        let result = try sut.parseCallbackURL(callbackURL)

        // Then: Should URL-decode the payload
        // Note: URLComponents automatically handles percent decoding for query items
        XCTAssertEqual(result.encryptedPayload, "hello world+=")
    }

    func testParseCallbackURL_WithMissingPayload_ThrowsError() throws {
        // Given: A callback URL without payload
        sut = makeTestableAuthManager()
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth?other=value")!

        // When/Then: Parsing should throw callbackMissingPayload
        XCTAssertThrowsError(try sut.parseCallbackURL(callbackURL)) { error in
            XCTAssertEqual(error as? DiscourseAuthError, .callbackMissingPayload)
        }
    }

    func testParseCallbackURL_WithEmptyFragment_ThrowsError() throws {
        // Given: A callback URL with empty fragment
        sut = makeTestableAuthManager()
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth#")!

        // When/Then: Parsing should throw callbackMissingPayload
        XCTAssertThrowsError(try sut.parseCallbackURL(callbackURL)) { error in
            XCTAssertEqual(error as? DiscourseAuthError, .callbackMissingPayload)
        }
    }

    func testParseCallbackURL_WithNoQueryOrFragment_ThrowsError() throws {
        // Given: A callback URL with no query or fragment
        sut = makeTestableAuthManager()
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth")!

        // When/Then: Parsing should throw callbackMissingPayload
        XCTAssertThrowsError(try sut.parseCallbackURL(callbackURL)) { error in
            XCTAssertEqual(error as? DiscourseAuthError, .callbackMissingPayload)
        }
    }
}

// MARK: - Character Extension

private extension Character {
    var isHexDigit: Bool {
        return self.isNumber || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}
