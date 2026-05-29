//
//  BackgroundRefreshCoordinator.swift
//  PIRATEN
//
//  Created by Claude Code on 22.04.26.
//
//  Runs the per-source polling loop executed by `BGAppRefreshTask` in the
//  background (and optionally on foreground resume). Unlike the previous
//  design — where notification dispatch lived in SwiftUI `.onChange`
//  observers inside MainTabView — this coordinator is a plain object and
//  runs with no view hierarchy. That is the fix for OPEN-12 / FR-NOTIF-004.
//
//  Contract (FR-NOTIF-003 / FR-NOTIF-004):
//  - Polls all six volatile sources: Forum, Messages, Todos, News,
//    Knowledge, Events.
//  - Each source is polled independently inside a TaskGroup child; a failure
//    in one source does NOT block the others.
//  - For each source that has new activity since the last background run,
//    consults `NotificationSettingsManager` for the category toggle. If
//    enabled, dispatches a local notification via `LocalNotificationScheduler`.
//  - The "last seen" counters are persisted in UserDefaults under `bg_*`
//    prefixed keys so they do not collide with the foreground ViewModels'
//    own `forum_last_seen_topic_id` etc. keys. The background and foreground
//    paths track new-content independently; both paths can dispatch a
//    notification for the same event, but each only once per its own
//    "last seen" marker.
//
//  Privacy: Only aggregate ids/counts are persisted — never item text.
//  Notification bodies MAY name the triggering item (topic title, message
//  sender + subject, todo/news title) when the poller can identify it; this
//  is built on the fly via `NotificationContentBuilder` and never stored.
//  Message bodies (sender + subject) are sensitive and stay hidden on the
//  lock screen via the iOS "Vorschau: Wenn entsperrt" system default — there
//  is no per-notification redaction API on iOS (see THREAT_MODEL.md T-007).
//  Wissen and Termine stay generic.
//

import Foundation

/// Coordinator invoked headless from `BGAppRefreshTask`. Polls every
/// enabled-and-authenticated source, updates the persisted "last seen"
/// counter, and fires a local notification via the shared scheduler
/// when something new is detected.
@MainActor
final class BackgroundRefreshCoordinator {

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository
    private let todoRepository: TodoRepository
    private let newsRepository: NewsRepository
    private let knowledgeRepository: KnowledgeRepository
    private let calendarRepository: CalendarRepository
    private let authRepository: AuthRepository
    private let settings: NotificationSettingsManager
    private let scheduler: LocalNotificationScheduling

    // MARK: - UserDefaults Keys
    //
    // Deliberately prefixed `bg_` so background-side state does not fight
    // the foreground ViewModel keys (`forum_last_seen_topic_id`, …). When
    // the user opens the app, each ViewModel runs its own comparison off
    // its own key. This double-tracking is intentional: it avoids a race
    // where the background clears the "new" flag before the UI has shown it.

    private enum Keys {
        static let forumLastId       = "bg_forum_last_seen_topic_id"
        static let messagesLastId    = "bg_messages_last_seen_thread_id"
        static let todosLastId       = "bg_todos_last_seen_todo_id"
        static let newsLastId        = "bg_news_last_seen_message_id"
        static let knowledgeLastId   = "bg_knowledge_last_seen_topic_id"
        static let eventsLastCount   = "bg_events_last_seen_count"
    }

    // MARK: - Init

    init(
        discourseRepository: DiscourseRepository,
        todoRepository: TodoRepository,
        newsRepository: NewsRepository,
        knowledgeRepository: KnowledgeRepository,
        calendarRepository: CalendarRepository,
        authRepository: AuthRepository,
        settings: NotificationSettingsManager,
        scheduler: LocalNotificationScheduling = LocalNotificationScheduler()
    ) {
        self.discourseRepository = discourseRepository
        self.todoRepository = todoRepository
        self.newsRepository = newsRepository
        self.knowledgeRepository = knowledgeRepository
        self.calendarRepository = calendarRepository
        self.authRepository = authRepository
        self.settings = settings
        self.scheduler = scheduler
    }

    // MARK: - Entry point

    /// Polls all six sources in parallel and dispatches local notifications
    /// for any source that (a) has new activity and (b) has its category
    /// toggle enabled in `NotificationSettingsManager`.
    ///
    /// Called from `BackgroundTaskScheduler.handleAppRefresh`. Safe to call
    /// from the foreground too if we ever want an explicit "check now".
    ///
    /// This method never throws: each source is isolated, and its failure
    /// is logged in DEBUG but does not abort the rest of the sweep.
    func run() async {
        // Short-circuit: if the user has not enabled any category, there's
        // nothing to dispatch. Still cheap enough that we could poll badge
        // counts, but the existing DiscourseNotificationPoller already
        // handles that concern independently.
        guard settings.anyNotificationsEnabled else {
            #if DEBUG
            print("[BackgroundRefreshCoordinator] All categories disabled — skipping sweep.")
            #endif
            return
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in await self?.pollForum() }
            group.addTask { [weak self] in await self?.pollMessages() }
            group.addTask { [weak self] in await self?.pollTodos() }
            group.addTask { [weak self] in await self?.pollNews() }
            group.addTask { [weak self] in await self?.pollKnowledge() }
            group.addTask { [weak self] in await self?.pollEvents() }
        }
    }

    // MARK: - Per-source pollers
    //
    // Each poller is stand-alone. Pattern:
    //   1. Fetch newest items.
    //   2. Compute the newest id (or count) for this source.
    //   3. Compare to the persisted last-seen marker.
    //   4. If increased AND the category is enabled, schedule.
    //   5. Persist the new marker regardless of the setting, so that
    //      flipping a category on later does not immediately flood the
    //      user with everything that accumulated while it was off.

    private func pollForum() async {
        do {
            let topics = try await discourseRepository.fetchTopics()
            let newestId = topics.map(\.id).max() ?? 0
            let lastSeen = UserDefaults.standard.integer(forKey: Keys.forumLastId)
            defer { UserDefaults.standard.set(newestId, forKey: Keys.forumLastId) }

            if lastSeen != 0, newestId > lastSeen, settings.forumEnabled {
                await scheduler.schedule(.forum, content: NotificationContentBuilder.forum(from: topics))
            }
        } catch {
            logFailure("forum", error)
        }
    }

    private func pollMessages() async {
        do {
            guard let user = await authRepository.getCurrentUser() else {
                #if DEBUG
                print("[BackgroundRefreshCoordinator] messages: not authenticated, skipping.")
                #endif
                return
            }
            // Skip the sent-mailbox fetch — for new-activity detection we
            // only care about the inbox and the extra request costs us a
            // rate-limit slot on Discourse (see Q-N6 in NOTIFICATIONS_TODO).
            let threads = try await discourseRepository.fetchMessageThreads(
                for: user.username,
                includeSent: false
            )
            let newestId = threads.map(\.id).max() ?? 0
            let lastSeen = UserDefaults.standard.integer(forKey: Keys.messagesLastId)
            defer { UserDefaults.standard.set(newestId, forKey: Keys.messagesLastId) }

            if lastSeen != 0, newestId > lastSeen, settings.messagesEnabled {
                await scheduler.schedule(.messages, content: NotificationContentBuilder.messages(from: threads))
            }
        } catch {
            logFailure("messages", error)
        }
    }

    private func pollTodos() async {
        do {
            let todos = try await todoRepository.fetchTodos()
            let newestId = todos.map(\.id).max() ?? 0
            let lastSeen = UserDefaults.standard.integer(forKey: Keys.todosLastId)
            defer { UserDefaults.standard.set(newestId, forKey: Keys.todosLastId) }

            if lastSeen != 0, newestId > lastSeen, settings.todosEnabled {
                await scheduler.schedule(.todos, content: NotificationContentBuilder.todos(from: todos))
            }
        } catch {
            logFailure("todos", error)
        }
    }

    private func pollNews() async {
        do {
            let items = try await newsRepository.fetchNews()
            // NewsItem.messageId is Int64; store as Int where representable,
            // otherwise clamp to Int.max — the delta is all we care about.
            let newestId64 = items.map(\.messageId).max() ?? 0
            let newestId = Int(clamping: newestId64)
            let lastSeen = UserDefaults.standard.integer(forKey: Keys.newsLastId)
            defer { UserDefaults.standard.set(newestId, forKey: Keys.newsLastId) }

            if lastSeen != 0, newestId > lastSeen, settings.newsEnabled {
                await scheduler.schedule(.news, content: NotificationContentBuilder.news(from: items))
            }
        } catch {
            logFailure("news", error)
        }
    }

    private func pollKnowledge() async {
        do {
            let index = try await knowledgeRepository.fetchIndex(forceRefresh: false)
            // Knowledge topic IDs are slugs (strings). Use lexicographic max
            // as the "newest" marker — same pattern KnowledgeViewModel uses.
            // This is imperfect (slugs aren't strictly monotonic) but it's
            // stable, equals-comparable, and matches the existing behaviour.
            let newestId = index.topics.map(\.id).max() ?? ""
            let lastSeen = UserDefaults.standard.string(forKey: Keys.knowledgeLastId)
            defer { UserDefaults.standard.set(newestId, forKey: Keys.knowledgeLastId) }

            if let lastSeen, !lastSeen.isEmpty, newestId != lastSeen, settings.knowledgeEnabled {
                await scheduler.schedule(.knowledge)
            }
        } catch {
            logFailure("knowledge", error)
        }
    }

    private func pollEvents() async {
        do {
            let events = try await calendarRepository.fetchEvents()
            // Calendar events have string UIDs; CalendarViewModel compares
            // counts (the iCal feed is a full rewrite, so any new event
            // bumps the count). Keep that heuristic here.
            let currentCount = events.count
            let lastSeen = UserDefaults.standard.integer(forKey: Keys.eventsLastCount)
            defer { UserDefaults.standard.set(currentCount, forKey: Keys.eventsLastCount) }

            if lastSeen != 0, currentCount > lastSeen, settings.eventsEnabled {
                await scheduler.schedule(.events)
            }
        } catch {
            logFailure("events", error)
        }
    }

    // MARK: - Logging

    private func logFailure(_ source: String, _ error: Error) {
        #if DEBUG
        print("[BackgroundRefreshCoordinator] \(source) poll failed: \(error)")
        #endif
    }

    // MARK: - Reset

    /// Clears all persisted last-seen markers. Call on logout to avoid
    /// the next login triggering "new activity" notifications for every
    /// item that accumulated since logout.
    func reset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.forumLastId)
        defaults.removeObject(forKey: Keys.messagesLastId)
        defaults.removeObject(forKey: Keys.todosLastId)
        defaults.removeObject(forKey: Keys.newsLastId)
        defaults.removeObject(forKey: Keys.knowledgeLastId)
        defaults.removeObject(forKey: Keys.eventsLastCount)
    }
}
