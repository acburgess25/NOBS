import SwiftUI
import UserNotifications

@main
struct NOBSApp: App {
    @StateObject private var model = AppModel()
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        Task { @MainActor in
            NotificationScheduler.registerCategories()
        }
    }

    var body: some Scene {
        WindowGroup {
            ConversationView()
                .environmentObject(model)
                .preferredColorScheme(.light)
                .onAppear {
                    AppModel.shared = model
                    notificationDelegate.model = model
                }
        }
    }
}
