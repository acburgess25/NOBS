import AppIntents
import Foundation

struct PrepareDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Prepare my day"
    static let description = IntentDescription("Build today's NOBS briefing from your calendar.")

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = await AppIntentSupport.prepareDay()
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct ExplainScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Explain today's schedule"
    static let description = IntentDescription("Summarize conflicts or unrealistic load in today's plan.")

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = await AppIntentSupport.explainSchedule()
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct AskNOBSIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask NOBS"
    static let description = IntentDescription("Open NOBS chat with a question.")

    static let openAppWhenRun = true

    @Parameter(title: "Question", requestValueDialog: IntentDialog("What should I ask NOBS?"))
    var prompt: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = await AppIntentSupport.askNOBS(prompt: prompt)
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

struct ShowPrivacyReceiptIntent: AppIntent {
    static let title: LocalizedStringResource = "Show privacy receipt"
    static let description = IntentDescription("Show what NOBS used and where it was processed.")

    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = await AppIntentSupport.showPrivacyReceipt()
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}
