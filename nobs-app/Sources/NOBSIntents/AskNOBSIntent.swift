import AppIntents
import NOBSAssistant

/// General-purpose AI query — the "ask your AI anything" intent.
/// Invokable from Siri, Shortcuts, Spotlight, and Control Center.
/// The app never opens.
public struct AskNOBSIntent: AppIntent {
    public static let title: LocalizedStringResource = "Ask NOBS"
    public static let description = IntentDescription(
        "Ask your private AI anything — runs on your device or your home server.",
        categoryName: "NOBS AI"
    )
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true

    @Parameter(title: "Question", requestValueDialog: "What do you want to ask NOBS?")
    public var question: String

    public init() {}
    public init(question: String) { self.question = question }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let assistant = IntentAssistant.make()
        let response = await assistant.process(question)
        return .result(dialog: IntentDialog(stringLiteral: response.text))
    }
}
