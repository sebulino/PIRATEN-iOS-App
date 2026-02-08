//
//  DeviceTokenManager.swift
//  PIRATEN
//
//  Created by Claude Code on 08.02.26.
//

import Foundation
import UIKit
import Combine

/// Manages APNs device token storage and registration.
/// Privacy note: Device tokens are non-sensitive data but are stored securely.
/// Tokens are only sent to backend when notification settings are enabled.
@MainActor
final class DeviceTokenManager: ObservableObject {

    // MARK: - Published State

    /// The current device token, if registered
    @Published private(set) var deviceToken: Data?

    /// Whether registration is in progress
    @Published private(set) var isRegistering = false

    /// Last registration error, if any
    @Published private(set) var lastError: Error?

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let deviceToken = "apns_device_token"
    }

    // MARK: - Initialization

    init() {
        // Load saved device token from UserDefaults (non-sensitive data)
        if let tokenData = UserDefaults.standard.data(forKey: Keys.deviceToken) {
            self.deviceToken = tokenData
        }
    }

    // MARK: - Public Methods

    /// Initiates APNs device token registration.
    /// Called when notification permission is granted.
    func registerForRemoteNotifications() {
        guard !isRegistering else { return }

        isRegistering = true
        lastError = nil

        // Register with APNs - callbacks handled via AppDelegate
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Stores the device token received from APNs.
    /// Called by AppDelegate when token is received.
    /// - Parameter token: The device token data from APNs
    func didReceiveDeviceToken(_ token: Data) {
        self.deviceToken = token
        self.isRegistering = false

        // Store token in UserDefaults (non-sensitive)
        UserDefaults.standard.set(token, forKey: Keys.deviceToken)

        // Privacy note: Never log full token
        #if DEBUG
        let tokenPrefix = token.prefix(2).map { String(format: "%02x", $0) }.joined()
        print("[DeviceTokenManager] Token registered: \(tokenPrefix)... (\(token.count) bytes)")
        #endif
    }

    /// Handles registration failure from APNs.
    /// Called by AppDelegate when registration fails.
    /// - Parameter error: The error from APNs
    func didFailToRegister(with error: Error) {
        self.lastError = error
        self.isRegistering = false

        #if DEBUG
        print("[DeviceTokenManager] Registration failed: \(type(of: error))")
        #endif
    }

    /// Returns the device token as a hex string for backend registration.
    /// - Returns: Hex string representation of the token, or nil if no token
    var deviceTokenString: String? {
        deviceToken?.map { String(format: "%02x", $0) }.joined()
    }

    /// Clears the stored device token.
    /// Called on logout to respect privacy.
    func clearDeviceToken() {
        deviceToken = nil
        UserDefaults.standard.removeObject(forKey: Keys.deviceToken)
    }
}
