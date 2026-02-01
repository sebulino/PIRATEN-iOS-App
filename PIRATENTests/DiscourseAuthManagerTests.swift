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

    // MARK: - Initialization Tests

    func testInit_WithValidConfiguration_Succeeds() {
        // Given: Configuration is present in Info.plist (from .xcconfig)
        // When: Creating DiscourseAuthManager
        // Then: Should succeed without throwing
        XCTAssertNoThrow(try DiscourseAuthManager(rsaKeyManager: rsaKeyManager))
    }

    // MARK: - Auth URL Building Tests

    func testBuildAuthURL_ContainsRequiredParameters() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)

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
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)

        // When: Building auth URL
        let url = try sut.buildAuthURL()

        // Then: URL should point to /user-api-key/new endpoint
        XCTAssertTrue(url.path.hasSuffix("/user-api-key/new"))
    }

    func testBuildAuthURL_NonceIsHexEncoded64Chars() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)

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
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)

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

    func testBuildAuthURL_ScopesAreReadOnly() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)

        // When: Building auth URL
        let url = try sut.buildAuthURL()

        // Then: Scopes should be limited to read-only operations
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let scopes = queryItems.first(where: { $0.name == "scopes" })?.value

        XCTAssertNotNil(scopes)
        XCTAssertTrue(scopes?.contains("notifications") ?? false)
        XCTAssertTrue(scopes?.contains("session_info") ?? false)
        // Verify no write scopes are present
        XCTAssertFalse(scopes?.contains("write") ?? true)
        XCTAssertFalse(scopes?.contains("post") ?? true)
    }

    func testBuildAuthURL_AuthRedirectUsesCustomScheme() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)

        // When: Building auth URL
        let url = try sut.buildAuthURL()

        // Then: auth_redirect should use the custom URL scheme
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let authRedirect = queryItems.first(where: { $0.name == "auth_redirect" })?.value

        XCTAssertNotNil(authRedirect)
        XCTAssertTrue(authRedirect?.hasPrefix("de.meine-piraten://") ?? false)
        XCTAssertTrue(authRedirect?.contains("discourse-auth") ?? false)
    }

    func testBuildAuthURL_StoresNonce() throws {
        // Given: A properly configured DiscourseAuthManager
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)

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
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)

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
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
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
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
        _ = try sut.buildAuthURL()
        let expectedNonce = sut.currentNonce!

        // When: Verifying with the same nonce
        let result = sut.verifyNonce(expectedNonce)

        // Then: Verification should succeed
        XCTAssertTrue(result)
    }

    func testVerifyNonce_WithDifferentNonce_ReturnsFalse() throws {
        // Given: A nonce was generated during auth URL building
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
        _ = try sut.buildAuthURL()

        // When: Verifying with a different nonce
        let result = sut.verifyNonce("0000000000000000000000000000000000000000000000000000000000000000")

        // Then: Verification should fail
        XCTAssertFalse(result)
    }

    func testVerifyNonce_WithNoStoredNonce_ReturnsFalse() throws {
        // Given: No nonce has been generated yet
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)

        // When: Attempting to verify a nonce
        let result = sut.verifyNonce("0000000000000000000000000000000000000000000000000000000000000000")

        // Then: Verification should fail
        XCTAssertFalse(result)
    }

    func testClearNonce_RemovesStoredNonce() throws {
        // Given: A nonce was generated during auth URL building
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
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
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth?payload=encryptedBase64Data123")!

        // When: Parsing the callback URL
        let result = try sut.parseCallbackURL(callbackURL)

        // Then: Should extract the payload
        XCTAssertEqual(result.encryptedPayload, "encryptedBase64Data123")
    }

    func testParseCallbackURL_WithPayloadInFragment_ExtractsPayload() throws {
        // Given: A callback URL with payload in fragment
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth#payload=encryptedBase64Data456")!

        // When: Parsing the callback URL
        let result = try sut.parseCallbackURL(callbackURL)

        // Then: Should extract the payload from fragment
        XCTAssertEqual(result.encryptedPayload, "encryptedBase64Data456")
    }

    func testParseCallbackURL_WithRawFragmentPayload_ExtractsPayload() throws {
        // Given: A callback URL with raw payload in fragment (no key=value)
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth#rawEncryptedPayload789")!

        // When: Parsing the callback URL
        let result = try sut.parseCallbackURL(callbackURL)

        // Then: Should extract the raw fragment as payload
        XCTAssertEqual(result.encryptedPayload, "rawEncryptedPayload789")
    }

    func testParseCallbackURL_WithURLEncodedPayload_DecodesPayload() throws {
        // Given: A callback URL with URL-encoded payload
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth?payload=hello%20world%2B%3D")!

        // When: Parsing the callback URL
        let result = try sut.parseCallbackURL(callbackURL)

        // Then: Should URL-decode the payload
        // Note: URLComponents automatically handles percent decoding for query items
        XCTAssertEqual(result.encryptedPayload, "hello world+=")
    }

    func testParseCallbackURL_WithMissingPayload_ThrowsError() throws {
        // Given: A callback URL without payload
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth?other=value")!

        // When/Then: Parsing should throw callbackMissingPayload
        XCTAssertThrowsError(try sut.parseCallbackURL(callbackURL)) { error in
            XCTAssertEqual(error as? DiscourseAuthError, .callbackMissingPayload)
        }
    }

    func testParseCallbackURL_WithEmptyFragment_ThrowsError() throws {
        // Given: A callback URL with empty fragment
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
        let callbackURL = URL(string: "de.meine-piraten://discourse-auth#")!

        // When/Then: Parsing should throw callbackMissingPayload
        XCTAssertThrowsError(try sut.parseCallbackURL(callbackURL)) { error in
            XCTAssertEqual(error as? DiscourseAuthError, .callbackMissingPayload)
        }
    }

    func testParseCallbackURL_WithNoQueryOrFragment_ThrowsError() throws {
        // Given: A callback URL with no query or fragment
        sut = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
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
