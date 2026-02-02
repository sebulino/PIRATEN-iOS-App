//
//  RSAKeyManagerTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 01.02.26.
//

import XCTest
@testable import PIRATEN

final class RSAKeyManagerTests: XCTestCase {

    var sut: RSAKeyManager!

    override func setUp() {
        super.setUp()
        sut = RSAKeyManager()
        // Clean up any existing keys before each test
        try? sut.deleteKeyPair()
    }

    override func tearDown() {
        // Clean up after each test
        try? sut.deleteKeyPair()
        sut = nil
        super.tearDown()
    }

    // MARK: - Key Generation Tests

    func testGenerateKeyPair_CreatesPrivateKey() throws {
        // When
        let privateKey = try sut.generateKeyPair()

        // Then
        XCTAssertNotNil(privateKey)
    }

    func testGenerateKeyPair_StoresKeyInKeychain() throws {
        // When
        _ = try sut.generateKeyPair()

        // Then
        let retrievedKey = try sut.getPrivateKey()
        XCTAssertNotNil(retrievedKey)
    }

    func testGenerateKeyPair_ReplacesExistingKey() throws {
        // Given
        let firstKey = try sut.generateKeyPair()
        let firstPublicKeyPEM = try sut.exportPublicKeyAsPEM(from: firstKey)

        // When
        let secondKey = try sut.generateKeyPair()
        let secondPublicKeyPEM = try sut.exportPublicKeyAsPEM(from: secondKey)

        // Then
        XCTAssertNotEqual(firstPublicKeyPEM, secondPublicKeyPEM, "New key should be different")
    }

    // MARK: - Key Retrieval Tests

    func testGetPrivateKey_ReturnsNilWhenNoKeyExists() throws {
        // When
        let key = try sut.getPrivateKey()

        // Then
        XCTAssertNil(key)
    }

    func testGetPrivateKey_ReturnsExistingKey() throws {
        // Given
        let originalKey = try sut.generateKeyPair()

        // When
        let retrievedKey = try sut.getPrivateKey()

        // Then
        XCTAssertNotNil(retrievedKey)

        // Verify it's the same key by comparing public keys
        let originalPEM = try sut.exportPublicKeyAsPEM(from: originalKey)
        let retrievedPEM = try sut.exportPublicKeyAsPEM(from: retrievedKey!)
        XCTAssertEqual(originalPEM, retrievedPEM)
    }

    // MARK: - PEM Export Tests

    func testExportPublicKeyAsPEM_ReturnsValidPEMFormat() throws {
        // Given
        let privateKey = try sut.generateKeyPair()

        // When
        let pem = try sut.exportPublicKeyAsPEM(from: privateKey)

        // Then
        XCTAssertTrue(pem.hasPrefix("-----BEGIN PUBLIC KEY-----"))
        XCTAssertTrue(pem.hasSuffix("-----END PUBLIC KEY-----"))
        XCTAssertTrue(pem.contains("\n"), "PEM should contain newlines")
    }

    func testExportPublicKeyAsPEM_ReturnsConsistentResultForSameKey() throws {
        // Given
        let privateKey = try sut.generateKeyPair()

        // When
        let pem1 = try sut.exportPublicKeyAsPEM(from: privateKey)
        let pem2 = try sut.exportPublicKeyAsPEM(from: privateKey)

        // Then
        XCTAssertEqual(pem1, pem2)
    }

    // MARK: - EnsureKeyPairExists Tests

    func testEnsureKeyPairExists_GeneratesKeyWhenNoneExists() throws {
        // When
        let key = try sut.ensureKeyPairExists()

        // Then
        XCTAssertNotNil(key)
        let retrievedKey = try sut.getPrivateKey()
        XCTAssertNotNil(retrievedKey)
    }

    func testEnsureKeyPairExists_ReusesExistingKey() throws {
        // Given
        let originalKey = try sut.generateKeyPair()
        let originalPEM = try sut.exportPublicKeyAsPEM(from: originalKey)

        // When
        let reusedKey = try sut.ensureKeyPairExists()
        let reusedPEM = try sut.exportPublicKeyAsPEM(from: reusedKey)

        // Then
        XCTAssertEqual(originalPEM, reusedPEM, "Should reuse existing key")
    }

    // MARK: - Delete Tests

    func testDeleteKeyPair_RemovesKeyFromKeychain() throws {
        // Given
        _ = try sut.generateKeyPair()
        XCTAssertNotNil(try sut.getPrivateKey(), "Key should exist before deletion")

        // When
        try sut.deleteKeyPair()

        // Then
        let key = try sut.getPrivateKey()
        XCTAssertNil(key, "Key should be deleted")
    }

    func testDeleteKeyPair_DoesNotThrowWhenNoKeyExists() throws {
        // When/Then
        XCTAssertNoThrow(try sut.deleteKeyPair())
    }

    // MARK: - Encryption/Decryption Tests

    func testDecrypt_CanDecryptEncryptedData() throws {
        // Given
        let privateKey = try sut.generateKeyPair()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            XCTFail("Could not derive public key")
            return
        }

        let plaintext = "Hello Discourse"
        let plaintextData = plaintext.data(using: .utf8)!

        // Encrypt with public key
        var encryptError: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(
            publicKey,
            .rsaEncryptionPKCS1,
            plaintextData as CFData,
            &encryptError
        ) as Data? else {
            XCTFail("Encryption failed")
            return
        }

        // When
        let decryptedData = try sut.decrypt(encryptedData, using: privateKey)

        // Then
        let decryptedString = String(data: decryptedData, encoding: .utf8)
        XCTAssertEqual(decryptedString, plaintext)
    }

}
