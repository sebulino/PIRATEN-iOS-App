import BackgroundTasks
import Foundation

/// Registers and handles the `BGAppRefreshTask` the app uses for headless
/// per-source notification polling (FR-NOTIF-003 / FR-NOTIF-004).
///
/// Handler pipeline per wake-up:
///   1. `BackgroundRefreshCoordinator.run()` polls all six volatile sources
///      (Forum, Messages, Todos, News, Knowledge, Events) in parallel and
///      dispatches local notifications for any source that has both new
///      activity AND an enabled per-category toggle.
///   2. `DiscourseNotificationPoller.poll()` refreshes the iOS home-screen
///      badge from Discourse's aggregate unread count.
///
/// Both steps run sequentially inside the `BGAppRefreshTask`'s `Task`.
/// The coordinator is the per-source work; the poller is a dumb badge
/// updater that existed before the coordinator and is kept for compat
/// (see OPEN-12 / NOTIFICATIONS_TODO.md §2.1).
final class BackgroundTaskScheduler {
    static let shared = BackgroundTaskScheduler()
    private let taskIdentifier = "ch.piratenpartei.piratEN.refresh"

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh() // Schedule next refresh

        // Capture the work reference so we can cancel cleanly on expiration.
        // MainActor hop is required: coordinator and poller are @MainActor.
        let work = Task { @MainActor in
            guard let container = AppContainer.shared else {
                task.setTaskCompleted(success: false)
                return
            }

            // Step 1: per-source polling + local notification dispatch.
            // This is the fix for OPEN-12 — notifications now originate
            // from a plain object, not from SwiftUI .onChange observers
            // (which don't fire while the app is backgrounded).
            await container.backgroundRefreshCoordinator.run()

            // Step 2: aggregate badge update from Discourse.
            // Kept separate because it hits a single cheap endpoint and
            // has its own last-known-total persistence.
            await container.notificationPoller.poll()

            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            // iOS is about to kill this wake-up (30s soft budget typical).
            // Cancel the in-flight work so we don't keep running after
            // setTaskCompleted has been called.
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
