import UserNotifications
import Foundation

final class NOBSNotificationManager {
    static let shared = NOBSNotificationManager()
    private init() {}

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        ) ?? false
    }

    func authorizationStatusText() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Enabled"
        case .denied:
            return "Denied in Settings"
        case .notDetermined:
            return "Not enabled"
        @unknown default:
            return "Unknown"
        }
    }

    func scheduleReminder(id: String, title: String, dueDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "NOBS Reminder"
        content.body = title
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("NOBS notification schedule failed: \(error)") }
        }
    }

    func cancelReminder(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
