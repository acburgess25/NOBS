import Foundation

struct IntroScene: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let narration: String
    let symbolName: String
    let tint: NOBSTint

    static let nobsIntro: [IntroScene] = [
        IntroScene(
            title: "Meet NOBS",
            subtitle: "Private family AI for Apple devices, local hubs, and the people you care about.",
            narration: "Welcome to NOBS. NOBS is private family AI for Apple devices, local home hubs, and the people you care about.",
            symbolName: "shield.lefthalf.filled",
            tint: .blue
        ),
        IntroScene(
            title: "Local First",
            subtitle: "Use your Mac, Mac mini, Linux box, iPhone, or iCloud memory before hosted compute.",
            narration: "NOBS starts local first. It prefers your Mac, your Mac mini, your Linux box, your iPhone, and your iCloud memory before hosted compute.",
            symbolName: "macmini",
            tint: .sage
        ),
        IntroScene(
            title: "Apple Family Ready",
            subtitle: "Invite adults, teens, kids, elders, and caregivers with clear role-based sharing.",
            narration: "NOBS is designed for Apple families. You can set up adults, teens, kids, elders, and caregivers with clear sharing roles.",
            symbolName: "person.3.sequence",
            tint: .amber
        ),
        IntroScene(
            title: "Permission First",
            subtitle: "NOBS proposes the plan, explains the access, and waits for confirmation before acting.",
            narration: "Before NOBS changes anything important, it proposes a plan, explains the access it needs, and waits for explicit confirmation.",
            symbolName: "checkmark.message",
            tint: .blue
        ),
        IntroScene(
            title: "Tank When Needed",
            subtitle: "Use Tank or a subscription only when the work needs hosted compute.",
            narration: "If a job is too large for local hardware, NOBS can use Tank beta access or a subscription tier, only when you choose that path.",
            symbolName: "server.rack",
            tint: .graphite
        )
    ]
}
