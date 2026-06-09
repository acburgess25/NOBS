import BackgroundTasks
import Foundation
import NOBSDatabase

final class NOBSBackgroundTaskManager {
    static let shared = NOBSBackgroundTaskManager()
    private let refreshIdentifier = "com.nobsdash.nobs.ai-refresh"
    private init() {}

    /// Call from App.init() — must be registered before the app finishes launching.
    func registerHandlers() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self?.handleAppRefresh(task: refreshTask)
        }
    }

    /// Schedule the next background refresh. Call when the app enters the background.
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // earliest: 1 hour
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("NOBSBackgroundTaskManager: failed to schedule refresh — \(error)")
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Always reschedule before doing work so the chain continues even if this run expires
        scheduleAppRefresh()

        let workTask = Task {
            // Lightweight work: ensure the database is ready for the foreground session
            try? NOBSDatabase.shared.setup(storageMode: .localOnly)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
