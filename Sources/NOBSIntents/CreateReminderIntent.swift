import AppIntents
import NOBSAssistant

/// Create a reminder — no app needed.
/// "Hey Siri, remind me to call the dentist tomorrow via NOBS"
public struct CreateReminderIntent: AppIntent {
    public static var title: LocalizedStringResource = "Create Reminder"
    public static var description = IntentDescription(
        "Create a reminder through your private AI.",
        categoryName: "NOBS AI"
    )
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Reminder", requestValueDialog: "What should I remind you about?")
    public var reminder: String

    public init() {}
    public init(reminder: String) { self.reminder = reminder }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let assistant = IntentAssistant.make()
        let response = await assistant.process("Remind me to \(reminder)")
        return .result(dialog: IntentDialog(stringLiteral: response.text))
    }
}

/// Send a message — no app needed.
/// "Hey Siri, tell Sarah I'm running late via NOBS"
public struct SendMessageIntent: AppIntent {
    public static var title: LocalizedStringResource = "Send Message"
    public static var description = IntentDescription(
        "Send a message through your private AI.",
        categoryName: "NOBS AI"
    )
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Recipient", requestValueDialog: "Who should I message?")
    public var recipient: String

    @Parameter(title: "Message", requestValueDialog: "What should I say?")
    public var message: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let assistant = IntentAssistant.make()
        let response = await assistant.process("Send a message to \(recipient): \(message)")
        return .result(dialog: IntentDialog(stringLiteral: response.text))
    }
}
