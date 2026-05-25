//
//  LogoutOrchestrator.swift
//  PIRATEN
//
//  Centralised logout fan-out introduced in response to security
//  audit finding H-2 (logout left significant state behind).
//

import Foundation
import UserNotifications
import os.log

private let logoutLog = Logger(subsystem: "de.meine-piraten.PIRATEN", category: "Logout")

/// Orchestrates a complete logout — every credential, cache, marker,
/// and preference that belongs to "the currently signed-in user"
/// must be cleared here. New stores added to the app belong on this list.
///
/// ## Why a separate orchestrator?
/// Before this audit, logout was a one-liner in `PIRATENApp.onLogout`:
/// it called `discourseAPIKeyProvider.clearCredential()` and
/// `authStateManager.logout()`. Twelve other stores leaked between
/// users — caches, drafts, "last seen" markers, notification settings,
/// the Discourse like-strategy preference, the RSA key pair. This file
/// is the single audit point: if you add a per-user store anywhere in
/// the app, add a line in `performLogout()` here too.
///
/// ## Pending revoke pattern
/// If the user taps "Abmelden" while offline, the server-side Discourse
/// User API Key revoke request can't go through — but the user expects
/// the local cleanup to happen anyway. We solve this with a "pending
/// revoke" slot in Keychain:
///
///  1. On revoke failure, the credential is copied to the pending slot
///     and *removed* from the active slot. The app behaves as logged out.
///  2. `drainPendingRevoke()` runs at every app launch with network. If
///     a pending credential exists, it retries the revoke. On success
///     the pending slot is cleared; on failure it stays for the next
///     attempt. Stored in Keychain (not UserDefaults) because the
///     credential is still a live Discourse token until the server
///     confirms revocation.
///
/// ## Order matters
/// 1. **Network-first** — revoke the Discourse User API Key on the
///    server *while we still have it*. After we clear local credentials
///    the only place to retry is the pending-revoke slot.
/// 2. **Credentials** — OIDC tokens, RSA key pair, Discourse credential.
/// 3. **Local data** — caches, drafts, last-seen markers.
/// 4. **Settings & notification state** — notification toggles back to
///    off, poller counts reset, delivered banners cleared.
///
/// ## Error handling
/// Every step swallows its error and logs via `os.Logger`. Logout must
/// always succeed from the user's perspective; partial failure (e.g.
/// network down, can't revoke server-side) enqueues a retry but does
/// not block local logout.
@MainActor
final class LogoutOrchestrator {

    // MARK: - Constants

    /// Keychain key for credentials awaiting a server-side revoke retry.
    /// Distinct from `DiscourseAuthManager.discourseCredentialKey` so an
    /// active session and a pending revoke can coexist (e.g. user logs
    /// out offline, logs back in before the next drain succeeds).
    static let pendingRevokeKey = "discourse_pending_revoke"

    // MARK: - Dependencies

    private let authRepository: AuthRepository
    private let discourseAuthManager: DiscourseAuthManager?
    private let discourseAPIKeyProvider: DiscourseAPIKeyProvider
    private let credentialStore: CredentialStore
    /// **Raw** HTTP client (NOT DiscourseHTTPClient). Used for the revoke
    /// call so we can set `User-Api-Key` explicitly — important for the
    /// drain path where the active credential is already gone.
    private let rawHTTPClient: HTTPClient
    private let rsaKeyManager: RSAKeyManager

    private let recentRecipientsStore: RecentRecipientsStorage
    private let messageDraftStore: MessageDraftStorage
    private let newsCacheStore: NewsCacheStore
    private let discourseCacheStore: DiscourseCacheStore
    private let readingProgressStore: ReadingProgressStorage
    private let knowledgeCacheManager: KnowledgeCacheManager

    private let notificationSettings: NotificationSettingsManager
    private let notificationPoller: DiscourseNotificationPoller
    private let backgroundRefreshCoordinator: BackgroundRefreshCoordinator

    // MARK: - Init

    init(
        authRepository: AuthRepository,
        discourseAuthManager: DiscourseAuthManager?,
        discourseAPIKeyProvider: DiscourseAPIKeyProvider,
        credentialStore: CredentialStore,
        rawHTTPClient: HTTPClient,
        rsaKeyManager: RSAKeyManager,
        recentRecipientsStore: RecentRecipientsStorage,
        messageDraftStore: MessageDraftStorage,
        newsCacheStore: NewsCacheStore,
        discourseCacheStore: DiscourseCacheStore,
        readingProgressStore: ReadingProgressStorage,
        knowledgeCacheManager: KnowledgeCacheManager,
        notificationSettings: NotificationSettingsManager,
        notificationPoller: DiscourseNotificationPoller,
        backgroundRefreshCoordinator: BackgroundRefreshCoordinator
    ) {
        self.authRepository = authRepository
        self.discourseAuthManager = discourseAuthManager
        self.discourseAPIKeyProvider = discourseAPIKeyProvider
        self.credentialStore = credentialStore
        self.rawHTTPClient = rawHTTPClient
        self.rsaKeyManager = rsaKeyManager
        self.recentRecipientsStore = recentRecipientsStore
        self.messageDraftStore = messageDraftStore
        self.newsCacheStore = newsCacheStore
        self.discourseCacheStore = discourseCacheStore
        self.readingProgressStore = readingProgressStore
        self.knowledgeCacheManager = knowledgeCacheManager
        self.notificationSettings = notificationSettings
        self.notificationPoller = notificationPoller
        self.backgroundRefreshCoordinator = backgroundRefreshCoordinator
    }

    // MARK: - Public entry points

    /// Performs a full logout. Always completes, even if individual steps fail.
    func performLogout() async {
        // 1. Network-first: revoke Discourse API key server-side while
        //    we still hold the credential. On failure, enqueue for retry.
        await attemptServerSideRevoke()

        // 2. Credentials — Discourse + RSA + OIDC.
        //    The revoke flow above does NOT touch local state; we do it
        //    here so a missing DiscourseAuthManager (config not loaded)
        //    or a network failure still results in local logout.
        discourseAPIKeyProvider.clearCredential()
        try? rsaKeyManager.deleteKeyPair()

        //    NOTE: Keycloak end-session-endpoint (RP-Initiated Logout)
        //    is not called here — see Docs/open-issues.md (post-v1).
        //    Local tokens are cleared which prevents reuse from this
        //    device; the IdP session ages out on its own.
        await authRepository.logout()

        // 3. Local data — caches, drafts, recent recipients, reading progress.
        recentRecipientsStore.clearAll()
        messageDraftStore.clearDraft()
        newsCacheStore.clearAll()
        discourseCacheStore.clearAll()
        readingProgressStore.clearAll()
        knowledgeCacheManager.clearCache()

        // 4. UserDefaults markers that aren't owned by a store object.
        RealDiscourseRepository.clearLikeStrategyCache()
        NewsViewModel.clearLastSeenMarker()
        backgroundRefreshCoordinator.reset()

        // 5. Notifications — toggles off, poller count zero, banners cleared.
        notificationSettings.clearAllSettings()
        notificationPoller.reset()
    }

    /// Retries any server-side revoke that previously failed (e.g. logout
    /// while offline). Safe to call multiple times and safe to call when
    /// nothing is pending — both no-op. Call from app launch as a
    /// fire-and-forget Task; this method never throws and never blocks UI.
    func drainPendingRevoke() async {
        guard let discourseAuthManager else {
            // No auth manager → no way to revoke. The pending slot will
            // sit there harmlessly until config is restored or the user
            // wipes the app.
            return
        }

        guard let credential = readPendingRevoke() else {
            // Nothing to drain.
            return
        }

        let success = await discourseAuthManager.performServerSideRevoke(
            apiKey: credential.apiKey,
            clientId: credential.clientId,
            httpClient: rawHTTPClient
        )

        if success {
            try? credentialStore.delete(forKey: Self.pendingRevokeKey)
            logoutLog.info("Drained pending Discourse revoke successfully")
        } else {
            // Leave it; next launch will retry. No log spam — drain runs
            // on every launch and a permanently-failing revoke would
            // flood Console.app otherwise.
        }
    }

    // MARK: - Private helpers

    private func attemptServerSideRevoke() async {
        guard let discourseAuthManager else {
            // Config missing — nothing to revoke server-side. Local
            // cleanup happens in performLogout() regardless.
            return
        }

        // Read the active credential. If there's nothing to revoke
        // (user never linked Discourse), we're done.
        guard let credential = try? await discourseAPIKeyProvider.getAPIKey() else {
            return
        }

        let success = await discourseAuthManager.performServerSideRevoke(
            apiKey: credential.apiKey,
            clientId: credential.clientId,
            httpClient: rawHTTPClient
        )

        if !success {
            // Enqueue for retry on next launch. The active credential
            // is about to be cleared by the caller — once that happens,
            // the pending slot is the *only* place that knows what to
            // revoke. So write before the active clear happens.
            enqueuePendingRevoke(credential)
            logoutLog.warning("Discourse revoke failed during logout — enqueued for retry")
        }
    }

    /// Serialises the credential into the pending slot. Best-effort: if
    /// the Keychain write fails (extremely rare), the user is still logged
    /// out locally; we just lose the retry opportunity.
    private func enqueuePendingRevoke(_ credential: DiscourseCredential) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(credential),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        try? credentialStore.set(json, forKey: Self.pendingRevokeKey)
    }

    /// Reads the pending credential, if any. Returns nil for the common
    /// "nothing pending" case as well as for any deserialisation failure
    /// — corrupt pending data is treated as "no pending" so it doesn't
    /// block future logouts.
    private func readPendingRevoke() -> DiscourseCredential? {
        guard let json = try? credentialStore.get(forKey: Self.pendingRevokeKey),
              let data = json.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DiscourseCredential.self, from: data)
    }
}
