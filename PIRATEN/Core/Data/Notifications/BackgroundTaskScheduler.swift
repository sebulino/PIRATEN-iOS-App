import BackgroundTasks
import Foundation

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

        guard let container = AppContainer.shared else {
            task.setTaskCompleted(success: false)
            return
        }
        let poller = container.notificationPoller

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            await poller.poll()
            task.setTaskCompleted(success: true)
        }
    }
}