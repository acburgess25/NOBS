import SwiftUI

@main
struct NOBSApp: App {
    var body: some Scene {
        WindowGroup {
            ConversationView()
                .preferredColorScheme(.light)
        }
    }
}

