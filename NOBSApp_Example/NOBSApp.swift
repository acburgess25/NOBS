import SwiftUI
import NOBSAssistant
import NOBSCore

@main
struct NOBSApp: App {
    // Shared assistant instance
    let assistant = NOBSAssistant(config: .localhost)
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView(assistant: assistant)
            }
        }
    }
}
