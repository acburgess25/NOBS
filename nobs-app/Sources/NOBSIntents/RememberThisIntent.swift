import AppIntents
import NOBSCore
import NOBSAssistant

/// Save something to NOBS memory — no app needed.
/// "Hey Siri, remember that my passport expires in March via NOBS"
public struct RememberThisIntent: AppIntent {
    public static let title: LocalizedStringResource = "Remember This"
    public static let description = IntentDescription(
        "Save something to your private AI memory.",
        categoryName: "NOBS AI"
    )
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "What to remember", requestValueDialog: "What should NOBS remember?")
    public var content: String

    @Parameter(title: "Context", default: .personal)
    public var context: IntentDataContext

    public init() {}
    public init(content: String) { self.content = content; self.context = .personal }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let assistant = IntentAssistant.make()
        let response = await assistant.process("Remember this: \(content)")
        return .result(dialog: IntentDialog(stringLiteral: response.text))
    }
}

/// Retrieve something from NOBS memory.
/// "Hey Siri, what do I know about my passport via NOBS"
public struct RecallMemoryIntent: AppIntent {
    public static let title: LocalizedStringResource = "Recall Memory"
    public static let description = IntentDescription(
        "Search your private AI memory.",
        categoryName: "NOBS AI"
    )
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "What to recall", requestValueDialog: "What should NOBS look up?")
    public var query: String

    public init() {}
    public init(query: String) { self.query = query }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let assistant = IntentAssistant.make()
        let response = await assistant.process("Recall: \(query)")
        return .result(dialog: IntentDialog(stringLiteral: response.text))
    }
}

// MARK: - Supporting enum

public enum IntentDataContext: String, AppEnum {
    case personal
    case work

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Context"
    public static let caseDisplayRepresentations: [IntentDataContext: DisplayRepresentation] = [
        .personal: "Personal",
        .work: "Work",
    ]
}
