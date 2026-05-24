import AppIntents

/// Registers NOBS with Siri, Shortcuts, and Spotlight automatically.
/// Siri will prompt for any parameters — e.g. "Ask NOBS" → Siri asks "What's your question?"
public struct NOBSShortcutsProvider: AppShortcutsProvider {

    public static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: AskNOBSIntent(),
                phrases: [
                    "Ask \(.applicationName)",
                    "Talk to \(.applicationName)",
                    "\(.applicationName) question",
                ],
                shortTitle: "Ask NOBS",
                systemImageName: "brain.head.profile"
            ),
            AppShortcut(
                intent: RememberThisIntent(),
                phrases: [
                    "\(.applicationName) remember something",
                    "Remember with \(.applicationName)",
                    "Save to \(.applicationName)",
                ],
                shortTitle: "Remember This",
                systemImageName: "brain"
            ),
            AppShortcut(
                intent: RecallMemoryIntent(),
                phrases: [
                    "\(.applicationName) recall",
                    "Search \(.applicationName) memory",
                    "What does \(.applicationName) know",
                ],
                shortTitle: "Recall Memory",
                systemImageName: "magnifyingglass"
            ),
            AppShortcut(
                intent: ControlHomeIntent(),
                phrases: [
                    "\(.applicationName) control home",
                    "Control home with \(.applicationName)",
                ],
                shortTitle: "Control Home",
                systemImageName: "homekit"
            ),
            AppShortcut(
                intent: RunSceneIntent(),
                phrases: [
                    "\(.applicationName) run scene",
                    "Run scene with \(.applicationName)",
                ],
                shortTitle: "Run Scene",
                systemImageName: "theatermasks.fill"
            ),
            AppShortcut(
                intent: CreateReminderIntent(),
                phrases: [
                    "\(.applicationName) remind me",
                    "Remind me with \(.applicationName)",
                ],
                shortTitle: "Create Reminder",
                systemImageName: "checklist"
            ),
            AppShortcut(
                intent: SendMessageIntent(),
                phrases: [
                    "\(.applicationName) send message",
                    "Send message with \(.applicationName)",
                ],
                shortTitle: "Send Message",
                systemImageName: "message.fill"
            )
        ]
    }
}