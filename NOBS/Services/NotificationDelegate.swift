import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    weak var model: AppModel?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let question = NotificationScheduler.prompt(from: userInfo) ?? ""
        let actionIdentifier = response.actionIdentifier
        let prompt = Self.resolvePrompt(
            actionIdentifier: actionIdentifier,
            question: question,
            conflict: NotificationScheduler.conflict(from: userInfo)
        )

        guard let prompt else { return }
        await MainActor.run { [weak model] in
            model?.handleDeepLink(chatPrompt: prompt)
        }
    }

    private static func resolvePrompt(
        actionIdentifier: String,
        question: String,
        conflict: ClarifyingConflict?
    ) -> String? {
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier, NotificationScheduler.actionOpen:
            return question.isEmpty ? nil : question
        case NotificationScheduler.actionDismiss:
            return nil
        default:
            guard actionIdentifier.hasPrefix(NotificationScheduler.actionKeepPrefix),
                  let conflict else {
                return question.isEmpty ? nil : question
            }
            let optionID = String(actionIdentifier.dropFirst(NotificationScheduler.actionKeepPrefix.count))
            let chosen = conflict.optionA.id == optionID ? conflict.optionA : conflict.optionB
            return "Help me keep \(chosen.label) as must-attend for today's overlap."
        }
    }
}
