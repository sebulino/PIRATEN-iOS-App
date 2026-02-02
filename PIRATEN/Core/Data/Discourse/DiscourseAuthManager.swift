//
//  DiscourseAuthManager.swift
//  PIRATEN
//
//  Created by Claude Code on 01.02.26.
//

import AuthenticationServices
import Foundation
import os.log

/// Logger for Discourse authentication debugging
private let discourseAuthLog = Logger(subsystem: "de.meine-piraten.PIRATEN", category: "DiscourseAuth")

/// Errors that can occur during Discourse authentication
enum DiscourseAuthError: Error, Equatable {
    case missingConfiguration(String)
    case invalidURL
    case nonceGenerationFailed
    case invalidPublicKey
    case authSessionCancelled
    case authSessionFailed(String)
    case callbackMissingPayload
    case invalidCallbackURL
    case invalidPayload
    case missingPrivateKey
    case nonceMismatch
    case decryptionFailed
    case notAuthenticated
}

/// Result of a successful Discourse auth callback containing the encrypted payload
struct DiscourseAuthCallbackResult {
    /// The encrypted payload (base64 encoded) containing the User API Key
    let encryptedPayload: String
}

/// Manages the Discourse User API Key authentication flow.
/// This class handles URL construction for the /user-api-key/new endpoint
/// following the official Discourse User API Keys specification.
///
/// ## Auth Flow
/// 1. Generate RSA key pair and nonce
/// 2. Build auth URL with all required parameters
/// 3. Open URL in ASWebAuthenticationSession (handled by caller)
/// 4. Receive callback with encrypted payload
/// 5. Decrypt and store User API Key
///
/// ## Security
/// - Nonce is cryptographically random (32 bytes, hex-encoded)
/// - Scopes limited to read-only operations initially
/// - Public key sent to Discourse for encrypting the response
///
/// Reference: https://meta.discourse.org/t/user-api-keys-specification/48536
final class DiscourseAuthManager {

    // MARK: - Configuration

    private let baseURL: String
    private let clientID: String
    private let redirectScheme: String
    private let redirectHost: String
    private let applicationName: String

    // MARK: - Dependencies

    private let rsaKeyManager: RSAKeyManager

    // MARK: - State

    /// The nonce for the current auth attempt, stored for verification
    private(set) var currentNonce: String?

    // MARK: - Initialization

    /// Creates a DiscourseAuthManager with configuration from Info.plist
    /// - Parameters:
    ///   - rsaKeyManager: Manager for RSA key operations
    /// - Throws: DiscourseAuthError.missingConfiguration if required config is missing
    init(rsaKeyManager: RSAKeyManager = RSAKeyManager()) throws {
        guard let baseURL = Bundle.main.infoDictionary?["DISCOURSE_BASE_URL"] as? String,
              !baseURL.isEmpty else {
            throw DiscourseAuthError.missingConfiguration("DISCOURSE_BASE_URL")
        }

        guard let clientID = Bundle.main.infoDictionary?["DISCOURSE_CLIENT_ID"] as? String,
              !clientID.isEmpty else {
            throw DiscourseAuthError.missingConfiguration("DISCOURSE_CLIENT_ID")
        }

        guard let redirectScheme = Bundle.main.infoDictionary?["DISCOURSE_AUTH_REDIRECT_SCHEME"] as? String,
              !redirectScheme.isEmpty else {
            throw DiscourseAuthError.missingConfiguration("DISCOURSE_AUTH_REDIRECT_SCHEME")
        }

        guard let redirectHost = Bundle.main.infoDictionary?["DISCOURSE_AUTH_REDIRECT_HOST"] as? String,
              !redirectHost.isEmpty else {
            throw DiscourseAuthError.missingConfiguration("DISCOURSE_AUTH_REDIRECT_HOST")
        }

        guard let applicationName = Bundle.main.infoDictionary?["DISCOURSE_APP_NAME"] as? String,
              !applicationName.isEmpty else {
            throw DiscourseAuthError.missingConfiguration("DISCOURSE_APP_NAME")
        }

        self.baseURL = baseURL
        self.clientID = clientID
        self.redirectScheme = redirectScheme
        self.redirectHost = redirectHost
        self.applicationName = applicationName
        self.rsaKeyManager = rsaKeyManager
    }

    // MARK: - Public Interface

    /// Builds the Discourse User API Key authentication URL.
    /// This URL should be opened in ASWebAuthenticationSession.
    ///
    /// - Returns: The complete auth URL with all required parameters
    /// - Throws: DiscourseAuthError if URL construction fails
    func buildAuthURL() throws -> URL {
        discourseAuthLog.info("Building Discourse auth URL...")
        discourseAuthLog.info("Base URL: \(self.baseURL)")
        discourseAuthLog.info("Client ID: \(self.clientID)")
        discourseAuthLog.info("Redirect: \(self.redirectScheme)://\(self.redirectHost)")
        discourseAuthLog.info("App Name: \(self.applicationName)")

        // Ensure RSA key pair exists
        let privateKey = try rsaKeyManager.ensureKeyPairExists()
        discourseAuthLog.info("RSA key pair ready")

        // Export public key in PEM format
        let publicKeyPEM = try rsaKeyManager.exportPublicKeyAsPEM(from: privateKey)
        discourseAuthLog.info("Public key PEM length: \(publicKeyPEM.count) characters")
        discourseAuthLog.debug("Public key PEM:\n\(publicKeyPEM)")

        // Generate cryptographically random nonce (32 bytes = 64 hex chars)
        guard let nonceData = generateNonce() else {
            discourseAuthLog.error("Failed to generate nonce")
            throw DiscourseAuthError.nonceGenerationFailed
        }
        let nonce = nonceData.hexEncodedString()
        self.currentNonce = nonce
        discourseAuthLog.info("Nonce generated: \(nonce.prefix(16))...")

        // Build redirect URL
        let authRedirect = "\(redirectScheme)://\(redirectHost)"

        // Scopes: Start with minimal read-only access
        // Note: 'notifications' and 'push' scopes require push_url parameter
        // Using 'read' and 'session_info' for basic forum access
        let scopes = "read,session_info"
        discourseAuthLog.info("Scopes: \(scopes)")

        // Build URL manually to ensure proper encoding of the public key
        // URLQueryItem doesn't encode + as %2B, which causes issues with PEM base64
        guard let baseURLWithPath = URL(string: "\(baseURL)/user-api-key/new") else {
            discourseAuthLog.error("Failed to build base URL")
            throw DiscourseAuthError.invalidURL
        }

        // Build query parameters with proper percent encoding
        // Use a custom character set that encodes +, /, = and newlines
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~") // RFC 3986 unreserved characters

        let queryParams = [
            ("client_id", clientID),
            ("nonce", nonce),
            ("auth_redirect", authRedirect),
            ("application_name", applicationName),
            ("public_key", publicKeyPEM),
            ("scopes", scopes)
        ]

        let queryString = queryParams
            .map { key, value in
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value
                return "\(key)=\(encodedValue)"
            }
            .joined(separator: "&")

        guard let url = URL(string: "\(baseURLWithPath.absoluteString)?\(queryString)") else {
            discourseAuthLog.error("Failed to construct final URL")
            throw DiscourseAuthError.invalidURL
        }

        discourseAuthLog.info("Auth URL built successfully")
        discourseAuthLog.info("Full URL length: \(url.absoluteString.count) characters")
        // Log the URL without the public key for readability
        let urlWithoutKey = url.absoluteString.components(separatedBy: "public_key=").first ?? ""
        discourseAuthLog.info("URL (truncated): \(urlWithoutKey)public_key=<...>")

        return url
    }

    /// Verifies that a nonce from the callback matches the one we sent
    /// - Parameter nonce: The nonce received in the callback
    /// - Returns: true if the nonce matches
    func verifyNonce(_ nonce: String) -> Bool {
        return nonce == currentNonce
    }

    /// Clears the current nonce after successful auth or on error
    func clearNonce() {
        currentNonce = nil
    }

    /// Starts the Discourse User API Key authentication flow using ASWebAuthenticationSession.
    /// Opens a web browser where the user completes SSO login, then receives the encrypted
    /// API key payload via the custom URL scheme callback.
    ///
    /// - Parameter presentationContextProvider: Provides the window anchor for presenting the auth session
    /// - Returns: The encrypted payload from Discourse containing the User API Key
    /// - Throws: DiscourseAuthError if authentication fails
    @MainActor
    func authenticate(
        presentationContextProvider: ASWebAuthenticationPresentationContextProviding
    ) async throws -> DiscourseAuthCallbackResult {
        // Build the auth URL (also generates and stores the nonce)
        let authURL = try buildAuthURL()

        // The callback URL scheme to intercept
        let callbackURLScheme = redirectScheme

        // Start the auth session
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackURLScheme
            ) { [weak self] callbackURL, error in
                if let error = error {
                    // Handle user cancellation
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        continuation.resume(throwing: DiscourseAuthError.authSessionCancelled)
                    } else {
                        continuation.resume(
                            throwing: DiscourseAuthError.authSessionFailed(error.localizedDescription)
                        )
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: DiscourseAuthError.invalidCallbackURL)
                    return
                }

                // Parse the callback URL to extract the encrypted payload
                do {
                    let result = try self?.parseCallbackURL(callbackURL)
                    if let result = result {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: DiscourseAuthError.invalidCallbackURL)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            session.presentationContextProvider = presentationContextProvider
            session.prefersEphemeralWebBrowserSession = false // Allow SSO session sharing

            session.start()
        }
    }

    /// Parses the callback URL from ASWebAuthenticationSession and extracts the encrypted payload.
    /// Discourse returns the encrypted User API Key as a URL fragment or query parameter.
    ///
    /// - Parameter url: The callback URL received from ASWebAuthenticationSession
    /// - Returns: The parsed callback result containing the encrypted payload
    /// - Throws: DiscourseAuthError if the URL cannot be parsed or is missing required data
    func parseCallbackURL(_ url: URL) throws -> DiscourseAuthCallbackResult {
        discourseAuthLog.info("Parsing callback URL: \(url.absoluteString)")

        // Discourse sends the payload as a query parameter or fragment
        // The URL format is: {scheme}://{host}?payload={encrypted_payload}
        // Or it may be in the fragment: {scheme}://{host}#{payload}

        // First, try query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            discourseAuthLog.info("URL scheme: \(components.scheme ?? "nil")")
            discourseAuthLog.info("URL host: \(components.host ?? "nil")")
            discourseAuthLog.info("URL query: \(components.query ?? "nil")")
            discourseAuthLog.info("URL fragment: \(components.fragment ?? "nil")")

            // Check query items for the payload
            if let queryItems = components.queryItems {
                discourseAuthLog.info("Query items count: \(queryItems.count)")
                for item in queryItems {
                    discourseAuthLog.info("Query item: \(item.name) = \(item.value?.prefix(50) ?? "nil")...")
                }
                // Discourse may use 'payload' or send the encrypted key directly
                if let payload = queryItems.first(where: { $0.name == "payload" })?.value {
                    discourseAuthLog.info("Found payload in query, length: \(payload.count)")
                    return DiscourseAuthCallbackResult(encryptedPayload: payload)
                }
            }

            // Check the fragment (Discourse sometimes puts data here)
            if let fragment = components.fragment, !fragment.isEmpty {
                discourseAuthLog.info("Fragment length: \(fragment.count)")
                // The fragment might contain the payload directly or as key=value
                if fragment.contains("=") {
                    // Parse fragment as query string
                    let fragmentComponents = fragment.components(separatedBy: "&")
                    for component in fragmentComponents {
                        let parts = component.components(separatedBy: "=")
                        if parts.count == 2, parts[0] == "payload" {
                            let payload = parts[1].removingPercentEncoding ?? parts[1]
                            discourseAuthLog.info("Found payload in fragment, length: \(payload.count)")
                            return DiscourseAuthCallbackResult(encryptedPayload: payload)
                        }
                    }
                } else {
                    // Fragment is the payload itself
                    let payload = fragment.removingPercentEncoding ?? fragment
                    discourseAuthLog.info("Fragment is payload, length: \(payload.count)")
                    return DiscourseAuthCallbackResult(encryptedPayload: payload)
                }
            }
        }

        discourseAuthLog.error("No payload found in callback URL")
        throw DiscourseAuthError.callbackMissingPayload
    }

    /// Completes the authentication flow by decrypting the payload, verifying the nonce,
    /// and storing the credential in the Keychain.
    ///
    /// This should be called after `authenticate()` returns the encrypted payload.
    ///
    /// - Parameters:
    ///   - encryptedPayload: The base64-encoded encrypted payload from the callback
    ///   - credentialStore: The credential store to save the API key credential
    /// - Returns: The decrypted and verified Discourse credential
    /// - Throws: DiscourseAuthError if decryption, verification, or storage fails
    func completeAuthentication(
        encryptedPayload: String,
        credentialStore: CredentialStore
    ) throws -> DiscourseCredential {
        discourseAuthLog.info("Completing authentication...")
        discourseAuthLog.info("Encrypted payload length: \(encryptedPayload.count)")

        // 1. Decode base64 payload (use ignoreUnknownCharacters to handle newlines from URL-encoding)
        guard let encryptedData = Data(base64Encoded: encryptedPayload, options: .ignoreUnknownCharacters) else {
            discourseAuthLog.error("Failed to decode base64 payload")
            throw DiscourseAuthError.invalidPayload
        }
        discourseAuthLog.info("Decoded encrypted data: \(encryptedData.count) bytes")

        // 2. Get private key
        guard let privateKey = try rsaKeyManager.getPrivateKey() else {
            discourseAuthLog.error("Private key not found")
            throw DiscourseAuthError.missingPrivateKey
        }
        discourseAuthLog.info("Private key retrieved")

        // 3. Decrypt the payload
        let decryptedData: Data
        do {
            decryptedData = try rsaKeyManager.decrypt(encryptedData, using: privateKey)
            discourseAuthLog.info("Decrypted data: \(decryptedData.count) bytes")
            if let decryptedString = String(data: decryptedData, encoding: .utf8) {
                discourseAuthLog.debug("Decrypted JSON: \(decryptedString)")
            }
        } catch {
            discourseAuthLog.error("Decryption failed: \(error)")
            throw DiscourseAuthError.decryptionFailed
        }

        // 4. Parse JSON response
        let response: DiscourseAuthResponse
        do {
            response = try JSONDecoder().decode(DiscourseAuthResponse.self, from: decryptedData)
            discourseAuthLog.info("Parsed response - nonce: \(response.nonce.prefix(16))...")
        } catch {
            discourseAuthLog.error("JSON decode failed: \(error)")
            throw DiscourseAuthError.invalidPayload
        }

        // 5. Verify nonce matches what we sent
        guard verifyNonce(response.nonce) else {
            throw DiscourseAuthError.nonceMismatch
        }
        clearNonce()

        // 6. Create and store credential
        let credential = DiscourseCredential(
            apiKey: response.key,
            clientId: clientID,
            createdAt: Date()
        )

        // Encode credential as JSON and store in Keychain
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encodedData = try encoder.encode(credential)
        guard let jsonString = String(data: encodedData, encoding: .utf8) else {
            throw DiscourseAuthError.invalidPayload
        }
        try credentialStore.set(jsonString, forKey: Self.discourseCredentialKey)

        return credential
    }

    /// The Keychain key used to store the Discourse credential
    static let discourseCredentialKey = "discourse_credential"

    /// Revokes the current Discourse API key and clears it from storage.
    /// This should be called during logout to ensure the key is invalidated server-side.
    ///
    /// - Parameters:
    ///   - httpClient: An HTTP client to use for the revocation request
    ///   - credentialStore: The credential store to clear the API key from
    /// - Note: If the server revocation fails, the local credential is still cleared.
    ///         This ensures the user is logged out even if the server is unreachable.
    func revokeAPIKey(
        httpClient: HTTPClient,
        credentialStore: CredentialStore
    ) async throws {
        // Attempt to revoke the key on the server
        // The revoke endpoint requires the User-Api-Key header to be set
        guard let revokeURL = URL(string: "\(baseURL)/user-api-key/revoke") else {
            // Can't build URL - just clear locally
            try credentialStore.delete(forKey: Self.discourseCredentialKey)
            return
        }

        let request = HTTPRequest(url: revokeURL, method: .post)

        // Try to revoke on server, but don't fail if it doesn't work
        // The important thing is to clear the local credential
        _ = try? await httpClient.execute(request)

        // Clear from Keychain regardless of server response
        try credentialStore.delete(forKey: Self.discourseCredentialKey)

        // Also delete the RSA key pair used for this auth session
        try rsaKeyManager.deleteKeyPair()
    }

    // MARK: - Private Helpers

    /// Generates a cryptographically random nonce using SecRandomCopyBytes
    /// - Returns: 32 bytes of random data, or nil if generation fails
    private func generateNonce() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            return nil
        }
        return Data(bytes)
    }
}

// MARK: - Data Extension

private extension Data {
    /// Converts data to a hex-encoded string
    func hexEncodedString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
