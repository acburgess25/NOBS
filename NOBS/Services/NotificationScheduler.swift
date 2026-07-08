import Foundation
import UserNotifications

enum NotificationScheduler {
    static let clarifyCategoryID = "NOBS_CLARIFY"
    static let clarifyNotificationID = "nobs.clarify.daily"
    static let eveningCategoryID = "NOBS_EVENING"
    static let eveningNotificationID = "nobs.evening.wrapup"
    static let actionOpen = "OPEN_NOBS"
    static let actionDismiss = "DISMISS"
    static let actionKeepPrefix = "KEEP_"

    static let permissionMessage = "NOBS can ask one quick question when your day needs a decision — not a stream of alerts."

    private static let lastScheduledDayKey = "nobs.clarify.lastScheduledDay"
    private static let lastEveningScheduledDayKey = "nobs.evening.lastScheduledDay"

    @MainActor
    static func registerCategories() {
        let open = UNNotificationAction(
            identifier: actionOpen,
            title: "Open in NOBS",
            options: [.foreground]
        )
        let dismiss = UNNotificationAction(
            identifier: actionDismiss,
            title: "Dismiss",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: clarifyCategoryID,
            actions: [open, dismiss],
            intentIdentifiers: [],
            options: []
        )
        let eveningOpen = UNNotificationAction(
            identifier: actionOpen,
            title: "Open wrap-up",
            options: [.foreground]
        )
        let eveningCategory = UNNotificationCategory(
            identifier: eveningCategoryID,
            actions: [eveningOpen, dismiss],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category, eveningCategory])
    }

    @MainActor
    static func refreshAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @MainActor
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    @MainActor
    static func scheduleClarifyingNotification(
        question: String,
        conflict: ClarifyingConflict?,
        allowsSchedule: Bool
    ) async -> Bool {
        registerCategories()
        guard allowsSchedule else {
            await cancelClarifyingNotification()
            return false
        }

        let trimmedQuestion = String(question.prefix(180))
        guard !trimmedQuestion.isEmpty else { return false }

        let today = dayStamp()
        if UserDefaults.standard.string(forKey: lastScheduledDayKey) == today {
            return false
        }

        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return false }

        await cancelClarifyingNotification()

        var actions: [UNNotificationAction] = [
            UNNotificationAction(identifier: actionOpen, title: "Open in NOBS", options: [.foreground]),
            UNNotificationAction(identifier: actionDismiss, title: "Dismiss", options: []),
        ]
        if let conflict {
            let keepA = UNNotificationAction(
                identifier: actionKeepPrefix + conflict.optionA.id,
                title: "Keep \(shortTitle(conflict.optionA.label))",
                options: [.foreground]
            )
            let keepB = UNNotificationAction(
                identifier: actionKeepPrefix + conflict.optionB.id,
                title: "Keep \(shortTitle(conflict.optionB.label))",
                options: [.foreground]
            )
            actions = [keepA, keepB, actions[0], actions[1]]
        }

        let category = UNNotificationCategory(
            identifier: clarifyCategoryID,
            actions: actions,
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        let content = UNMutableNotificationContent()
        content.title = "NOBS — quick question"
        content.body = trimmedQuestion
        content.categoryIdentifier = clarifyCategoryID
        content.sound = .default
        content.userInfo = userInfo(question: trimmedQuestion, conflict: conflict)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 90, repeats: false)
        let request = UNNotificationRequest(identifier: clarifyNotificationID, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            UserDefaults.standard.set(today, forKey: lastScheduledDayKey)
            return true
        } catch {
            return false
        }
    }

    @MainActor
    static func cancelEveningWrapUpNotification() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [eveningNotificationID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [eveningNotificationID])
    }

    @MainActor
    static func scheduleEveningWrapUpNotification(
        topline: String,
        allowsSchedule: Bool
    ) async -> Bool {
        registerCategories()
        guard allowsSchedule else {
            await cancelEveningWrapUpNotification()
            return false
        }

        let trimmed = String(topline.prefix(180))
        guard !trimmed.isEmpty else { return false }

        let today = dayStamp()
        if UserDefaults.standard.string(forKey: lastEveningScheduledDayKey) == today {
            return false
        }

        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return false }

        await cancelEveningWrapUpNotification()

        let content = UNMutableNotificationContent()
        content.title = "NOBS — evening wrap-up"
        content.body = trimmed
        content.categoryIdentifier = eveningCategoryID
        content.sound = .default
        content.userInfo = ["topline": trimmed, "kind": "evening"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 90, repeats: false)
        let request = UNNotificationRequest(identifier: eveningNotificationID, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            UserDefaults.standard.set(today, forKey: lastEveningScheduledDayKey)
            return true
        } catch {
            return false
        }
    }

    @MainActor
    static func cancelClarifyingNotification() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [clarifyNotificationID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [clarifyNotificationID])
    }

    static func userInfo(question: String, conflict: ClarifyingConflict?) -> [AnyHashable: Any] {
        var info: [AnyHashable: Any] = ["question": question]
        if let conflict,
           let data = try? JSONEncoder().encode(conflict),
           let json = String(data: data, encoding: .utf8) {
            info["conflict"] = json
        }
        return info
    }

    static func prompt(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo["question"] as? String
    }

    static func conflict(from userInfo: [AnyHashable: Any]) -> ClarifyingConflict? {
        guard let json = userInfo["conflict"] as? String,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ClarifyingConflict.self, from: data)
    }

    private static func dayStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func shortTitle(_ value: String) -> String {
        if value.count <= 18 { return value }
        return String(value.prefix(15)) + "…"
    }
}
