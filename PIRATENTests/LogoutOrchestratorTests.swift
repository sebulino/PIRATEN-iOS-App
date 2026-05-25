//
//  LogoutOrchestratorTests.swift
//  PIRATENTests
//
//  Coverage for security audit finding H-2: logout fan-out.
//  Each test asserts that a specific store / marker / setting is cleared
//  by performLogout(). The point of this file is regression-protection:
//  if a future change unwires the orchestrator from a store, one of
//  these tests should fail.
//

import Foundation
import Testing
@testable import PIRATEN

@MainActor
struct LogoutOrchestratorTests {

    // MARK: - Test scaffolding

    /// Builds an orchestrator wired to real stores backed by the standard
    /// UserDefaults / in-memory state. We don't mock — the goal is to
    /// verify the fan-out actually touches each store's external state.
    private static func makeOrchestrator() -> (
        orchestrator: LogoutOrchestrator,
        deps: LogoutTestDependencies
    ) {
        let credentialStore = InMemoryCredentialStore()
        let authRepo = FakeAuthRepository(credentialStore: credentialStore)
        let apiKeyProvider = KeychainDiscourseAPIKeyProvider(credentialStore: credentialStore)
        let recentRecipients = RecentRecipientsStore()
        let messageDraft = MessageDraftStore()
        let newsCache = NewsCacheStore()
        let discourseCache = DiscourseCacheStore()
        let readingProgress = ReadingProgressStore()
        let knowledgeCache = KnowledgeCacheManager()
        let settings = NotificationSettingsManager()
        let poller = DiscourseNotificationPoller(
            httpClient: StubHTTPClient(),
            baseURL: URL(string: "https://example.com")!,
            notificationSettingsManager: settings
        )
        let bgCoordinator = BackgroundRefreshCoordinator(
            discourseRepository: FakeDiscourseRepository(),
            todoRepository: FakeTodoRepository(),
            newsRepository: FakeNewsRepository(),
            knowledgeRepository: FakeKnowledgeRepository(),
            calendarRepository: FakeCalendarRepository(),
            authRepository: authRepo,
            settings: settings,
            scheduler: LocalNotificationScheduler()
        )

        let orchestrator = LogoutOrchestrator(
            authRepository: authRepo,
            discourseAuthManager: nil,
            discourseAPIKeyProvider: apiKeyProvider,
            credentialStore: credentialStore,
            rawHTTPClient: StubHTTPClient(),
            rsaKeyManager: RSAKeyManager(),
            recentRecipientsStore: recentRecipients,
            messageDraftStore: messageDraft,
            newsCacheStore: newsCache,
            discourseCacheStore: discourseCache,
            readingProgressStore: readingProgress,
            knowledgeCacheManager: knowledgeCache,
            notificationSettings: settings,
            notificationPoller: poller,
            backgroundRefreshCoordinator: bgCoordinator
        )

        let deps = LogoutTestDependencies(
            credentialStore: credentialStore,
            recentRecipients: recentRecipients,
            messageDraft: messageDraft,
            settings: settings
        )
        return (orchestrator, deps)
    }

    // MARK: - Setup state we will assert is cleared

    private static func seedStateBeforeLogout(_ deps: LogoutTestDependencies) {
        // Recent recipients
        deps.recentRecipients.addRecipient("piratemate")

        // Message draft
        deps.messageDraft.saveDraft(MessageDraft(
            recipientUsername: "piratemate",
            recipientDisplayName: "Pirate Mate",
            subject: "Test",
            body: "Hello",
            savedAt: Date()
        ))

        // Notification toggles — explicitly turn on ALL of them, including
        // the two new ones (knowledge/events) that audit M-2 / H-2 flagged.
        deps.settings.messagesEnabled = true
        deps.settings.forumEnabled = true
        deps.settings.todosEnabled = true
        deps.settings.newsEnabled = true
        deps.settings.knowledgeEnabled = true
        deps.settings.eventsEnabled = true

        // UserDefaults markers owned by static helpers
        UserDefaults.standard.set(42, forKey: NewsViewModel.lastSeenNewsKey)
        UserDefaults.standard.set("post-actions-form", forKey: "discourse_like_winning_strategy")
        UserDefaults.standard.set(99, forKey: "bg_forum_last_seen_topic_id")

        // Credential
        try? deps.credentialStore.set("fake-api-key", forKey: DiscourseAuthManager.discourseCredentialKey)
    }

    // MARK: - Tests

    @Test func clearsRecentRecipients() async {
        let (orchestrator, deps) = Self.makeOrchestrator()
        Self.seedStateBeforeLogout(deps)
        #expect(!deps.recentRecipients.getRecentRecipients().isEmpty)

        await orchestrator.performLogout()

        #expect(deps.recentRecipients.getRecentRecipients().isEmpty)
    }

    @Test func clearsMessageDraft() async {
        let (orchestrator, deps) = Self.makeOrchestrator()
        Self.seedStateBeforeLogout(deps)
        #expect(deps.messageDraft.getDraft() != nil)

        await orchestrator.performLogout()

        #expect(deps.messageDraft.getDraft() == nil)
    }

    @Test func clearsAllNotificationToggles() async {
        let (orchestrator, deps) = Self.makeOrchestrator()
        Self.seedStateBeforeLogout(deps)

        await orchestrator.performLogout()

        #expect(!deps.settings.messagesEnabled)
        #expect(!deps.settings.forumEnabled)
        #expect(!deps.settings.todosEnabled)
        #expect(!deps.settings.newsEnabled)
        // Regression guards for H-2 / M-2:
        #expect(!deps.settings.knowledgeEnabled)
        #expect(!deps.settings.eventsEnabled)
    }

    @Test func clearsDiscourseCredential() async {
        let (orchestrator, deps) = Self.makeOrchestrator()
        Self.seedStateBeforeLogout(deps)
        #expect(deps.credentialStore.contains(key: DiscourseAuthManager.discourseCredentialKey))

        await orchestrator.performLogout()

        #expect(!deps.credentialStore.contains(key: DiscourseAuthManager.discourseCredentialKey))
    }

    @Test func clearsLikeStrategyCache() async {
        let (orchestrator, _) = Self.makeOrchestrator()
        UserDefaults.standard.set("post-actions-form", forKey: "discourse_like_winning_strategy")

        await orchestrator.performLogout()

        #expect(UserDefaults.standard.string(forKey: "discourse_like_winning_strategy") == nil)
    }

    @Test func clearsNewsLastSeenMarker() async {
        let (orchestrator, _) = Self.makeOrchestrator()
        UserDefaults.standard.set(42, forKey: NewsViewModel.lastSeenNewsKey)

        await orchestrator.performLogout()

        #expect(UserDefaults.standard.object(forKey: NewsViewModel.lastSeenNewsKey) == nil)
    }

    @Test func clearsBackgroundRefreshMarkers() async {
        let (orchestrator, _) = Self.makeOrchestrator()
        // Seed one of the bg_ markers
        UserDefaults.standard.set(99, forKey: "bg_forum_last_seen_topic_id")
        UserDefaults.standard.set(99, forKey: "bg_messages_last_seen_thread_id")
        UserDefaults.standard.set(99, forKey: "bg_news_last_seen_message_id")

        await orchestrator.performLogout()

        #expect(UserDefaults.standard.object(forKey: "bg_forum_last_seen_topic_id") == nil)
        #expect(UserDefaults.standard.object(forKey: "bg_messages_last_seen_thread_id") == nil)
        #expect(UserDefaults.standard.object(forKey: "bg_news_last_seen_message_id") == nil)
    }

    @Test func completesEvenWithNoDiscourseAuthManager() async {
        // The audit warned that nil-ing out DiscourseAuthManager (which
        // happens when Discourse config is missing) must not block logout.
        let (orchestrator, _) = Self.makeOrchestrator()

        // Should not throw / hang — we just want it to return.
        await orchestrator.performLogout()
    }

    // MARK: - Pending revoke (offline-logout follow-up)

    @Test func drainIsNoOpWhenNothingPending() async {
        let (orchestrator, deps) = Self.makeOrchestrator()
        #expect(!deps.credentialStore.contains(key: LogoutOrchestrator.pendingRevokeKey))

        // Should complete immediately, no throw.
        await orchestrator.drainPendingRevoke()

        #expect(!deps.credentialStore.contains(key: LogoutOrchestrator.pendingRevokeKey))
    }

    @Test func drainIsNoOpWhenDiscourseAuthManagerMissing() async {
        // With discourseAuthManager == nil there's no way to call revoke.
        // The pending entry should be left in place for a future drain
        // when config might be present.
        let (orchestrator, deps) = Self.makeOrchestrator()
        let credential = sampleCredential()
        try? deps.credentialStore.set(
            encodeCredential(credential),
            forKey: LogoutOrchestrator.pendingRevokeKey
        )

        await orchestrator.drainPendingRevoke()

        // Still there — orchestrator didn't lose it.
        #expect(deps.credentialStore.contains(key: LogoutOrchestrator.pendingRevokeKey))
    }

    @Test func pendingRevokeKeyHasStablePublicName() {
        // The Keychain key name is part of the on-device contract: if a
        // future refactor renames it, the existing pending revokes on
        // upgraded devices would be orphaned. Pin the name with a test.
        #expect(LogoutOrchestrator.pendingRevokeKey == "discourse_pending_revoke")
    }

    // MARK: - Pending revoke helpers

    private func sampleCredential() -> DiscourseCredential {
        DiscourseCredential(
            apiKey: "test-api-key-deadbeef",
            clientId: "test-client-id",
            createdAt: Date()
        )
    }

    private func encodeCredential(_ credential: DiscourseCredential) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(credential),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - Test helpers

/// Bag of references handed back from makeOrchestrator so each test can
/// inspect the state without re-plumbing the construction.
@MainActor
private struct LogoutTestDependencies {
    let credentialStore: InMemoryCredentialStore
    let recentRecipients: RecentRecipientsStore
    let messageDraft: MessageDraftStore
    let settings: NotificationSettingsManager
}
