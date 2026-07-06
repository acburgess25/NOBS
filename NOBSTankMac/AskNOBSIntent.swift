import AppIntents
import Foundation

/// Exposes "Ask NOBS Tank" to Siri, Spotlight, and Shortcuts on macOS 27.
/// Read-only: it asks a question and returns the answer with its route.
/// It never triggers state changes, so no confirmation step is required.
struct AskNOBSIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask NOBS Tank"
    static let description = IntentDescription(
        "Ask the NOBS assistant on this Mac. Uses your private Tank when it is running, otherwise the on-device model."
    )

    @Parameter(title: "Question")
    var question: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let supervisor = await TankSupervisor(polling: false)
        await supervisor.refresh()

        if await supervisor.serverStatus == .running,
           let token = await supervisor.deviceToken {
            if let reply = try? await TankClient().chat(
                baseURL: supervisor.serverURL, token: token, message: question) {
                return .result(dialog: "\(reply.message) (\(reply.route))")
            }
        }
        let localAnswer = try await LocalAssistant().respond(to: question)
        return .result(dialog: "\(localAnswer) (Local)")
    }
}

struct NOBSTankShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskNOBSIntent(),
            phrases: ["Ask \(.applicationName)"],
            shortTitle: "Ask NOBS",
            systemImageName: "shippingbox"
        )
    }
}
