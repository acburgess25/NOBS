import AppIntents
import NOBSAssistant

/// Control a smart home device with natural language — no app needed.
/// "Hey Siri, turn off the living room lights via NOBS"
public struct ControlHomeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Control Home"
    public static var description = IntentDescription(
        "Control your smart home with natural language via your private AI.",
        categoryName: "NOBS AI"
    )
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Command", requestValueDialog: "What do you want to control?")
    public var command: String

    public init() {}
    public init(command: String) { self.command = command }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let assistant = IntentAssistant.make()
        let response = await assistant.process(command)
        return .result(dialog: IntentDialog(stringLiteral: response.text))
    }
}

/// Run a HomeKit scene — no app needed.
/// "Hey Siri, run my movie scene via NOBS"
public struct RunSceneIntent: AppIntent {
    public static var title: LocalizedStringResource = "Run Scene"
    public static var description = IntentDescription(
        "Run a HomeKit scene through your private AI.",
        categoryName: "NOBS AI"
    )
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Scene name", requestValueDialog: "Which scene should I run?")
    public var sceneName: String

    public init() {}
    public init(sceneName: String) { self.sceneName = sceneName }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let assistant = IntentAssistant.make()
        let response = await assistant.process("Run the \(sceneName) scene")
        return .result(dialog: IntentDialog(stringLiteral: response.text))
    }
}
