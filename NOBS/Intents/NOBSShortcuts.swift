import AppIntents

struct NOBSShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PrepareDayIntent(),
            phrases: [
                "Prepare my day in \(.applicationName)",
                "Prep my day with \(.applicationName)",
            ],
            shortTitle: "Prepare day",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: ExplainScheduleIntent(),
            phrases: [
                "What's unrealistic today in \(.applicationName)",
                "Explain my schedule in \(.applicationName)",
            ],
            shortTitle: "Explain schedule",
            systemImageName: "exclamationmark.triangle"
        )
        AppShortcut(
            intent: AskNOBSIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Open \(.applicationName) chat",
            ],
            shortTitle: "Ask NOBS",
            systemImageName: "message"
        )
        AppShortcut(
            intent: ShowPrivacyReceiptIntent(),
            phrases: [
                "Show \(.applicationName) privacy receipt",
            ],
            shortTitle: "Privacy receipt",
            systemImageName: "hand.raised"
        )
    }
}
