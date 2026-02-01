//
//  DiscourseAuthManager.swift
//  PIRATEN
//
//  Created by Claude Code on 01.02.26.
//

import AuthenticationServices
import Foundation

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
        // Ensure RSA key pair exists
        let privateKey = try rsaKeyManager.ensureKeyPairExists()

        // Export public key in PEM format
        let publicKeyPEM = try rsaKeyManager.exportPublicKeyAsPEM(from: privateKey)

        // Generate cryptographically random nonce (32 bytes = 64 hex chars)
        guard let nonceData = generateNonce() else {
            throw DiscourseAuthError.nonceGenerationFailed
        }
        let nonce = nonceData.hexEncodedString()
        self.currentNonce = nonce

        // Build redirect URL
        let authRedirect = "\(redirectScheme)://\(redirectHost)"

        // Scopes: Start with minimal read-only access
        // notifications: receive push notifications
        // session_info: get basic session information
        let scopes = "notifications,session_info"

        // Build URL components
        var components = URLComponents(string: "\(baseURL)/user-api-key/new")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "auth_redirect", value: authRedirect),
            URLQueryItem(name: "application_name", value: applicationName),
            URLQueryItem(name: "public_key", value: publicKeyPEM),
            URLQueryItem(name: "scopes", value: scopes)
        ]

        guard let url = components?.url else {
            throw DiscourseAuthError.invalidURL
        }

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
        // Discourse sends the payload as a query parameter or fragment
        // The URL format is: {scheme}://{host}?payload={encrypted_payload}
        // Or it may be in the fragment: {scheme}://{host}#{payload}

        // First, try query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // Check query items for the payload
            if let queryItems = components.queryItems {
                // Discourse may use 'payload' or send the encrypted key directly
                if let payload = queryItems.first(where: { $0.name == "payload" })?.value {
                    return DiscourseAuthCallbackResult(encryptedPayload: payload)
                }
            }

            // Check the fragment (Discourse sometimes puts data here)
            if let fragment = components.fragment, !fragment.isEmpty {
                // The fragment might contain the payload directly or as key=value
                if fragment.contains("=") {
                    // Parse fragment as query string
                    let fragmentComponents = fragment.components(separatedBy: "&")
                    for component in fragmentComponents {
                        let parts = component.components(separatedBy: "=")
                        if parts.count == 2, parts[0] == "payload" {
                            let payload = parts[1].removingPercentEncoding ?? parts[1]
                            return DiscourseAuthCallbackResult(encryptedPayload: payload)
                        }
                    }
                } else {
                    // Fragment is the payload itself
                    let payload = fragment.removingPercentEncoding ?? fragment
                    return DiscourseAuthCallbackResult(encryptedPayload: payload)
                }
            }
        }

        throw DiscourseAuthError.callbackMissingPayload
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
