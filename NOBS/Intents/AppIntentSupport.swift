import Foundation

enum AppIntentSupport {
    @MainActor
    static func prepareDay() async -> String {
        if let model = AppModel.shared {
            return await model.prepareDayIntentDialog()
        }
        return cachedPrepareDayDialog()
    }

    @MainActor
    static func explainSchedule() async -> String {
        if let model = AppModel.shared {
            return await model.explainScheduleIntentDialog()
        }
        return cachedExplainScheduleDialog()
    }

    @MainActor
    static func askNOBS(prompt: String) async -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "What would you like to ask NOBS?"
        }
        if let model = AppModel.shared {
            return await model.askNOBSIntentDialog(prompt: trimmed)
        }
        return "Open NOBS to ask: \(trimmed)"
    }

    @MainActor
    static func showPrivacyReceipt() async -> String {
        if let model = AppModel.shared {
            return await model.showPrivacyReceiptIntentDialog()
        }
        return cachedPrivacyReceiptDialog()
    }

    static func cachedPrepareDayDialog() -> String {
        guard let briefing: DailyBriefing = try? AppGroupStore.readJSON(DailyBriefing.self, from: AppGroupStore.latestBriefingFile) else {
            return "Open NOBS on Today to connect your calendar and build a plan."
        }
        return formatPrepareDay(briefing)
    }

    static func cachedExplainScheduleDialog() -> String {
        guard let briefing: DailyBriefing = try? AppGroupStore.readJSON(DailyBriefing.self, from: AppGroupStore.latestBriefingFile) else {
            return "Open NOBS on Today to connect your calendar and check today's plan."
        }
        return formatExplainSchedule(briefing)
    }

    static func cachedPrivacyReceiptDialog() -> String {
        guard let briefing: DailyBriefing = try? AppGroupStore.readJSON(DailyBriefing.self, from: AppGroupStore.latestBriefingFile) else {
            return "Open NOBS Privacy to see what was used and where it was processed."
        }
        return formatReceipt(briefing.privacyReceipt)
    }

    static func formatPrepareDay(_ briefing: DailyBriefing) -> String {
        let priority = briefing.priorities.first ?? "No priorities listed yet."
        return "\(briefing.topline) Top priority: \(priority). \(routeLabel(briefing.route))."
    }

    static func formatExplainSchedule(_ briefing: DailyBriefing) -> String {
        let risks = briefing.conflictsOrRisks.filter {
            !$0.localizedCaseInsensitiveContains("no major")
        }
        if risks.isEmpty {
            return "Nothing unrealistic stood out in your latest briefing. \(routeLabel(briefing.route))."
        }
        return "\(risks.prefix(2).joined(separator: " ")) \(routeLabel(briefing.route))."
    }

    static func formatReceipt(_ receipt: PrivacyReceipt) -> String {
        let used = receipt.used.joined(separator: ", ")
        return "Used \(used). Processed \(receipt.processed)."
    }

    static func routeLabel(_ route: ProcessingRoute) -> String {
        switch route {
        case .local:
            "Processed on this iPhone"
        case .onDeviceAI:
            "Processed with on-device AI"
        case .tank:
            "Refined on Tank"
        case .cloud:
            "Processed on NOBScloud"
        }
    }
}
