import SwiftUI

@main
struct NOBSApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ConversationView()
                .environmentObject(model)
                .preferredColorScheme(.light)
        }
    }
}
