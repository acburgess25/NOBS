import Foundation

enum BriefingCoordinator {
    static func dayRescueState(
        from briefing: DailyBriefing?,
        eventCount: Int,
        clarifyingConflict: ClarifyingConflict?
    ) -> DayRescueState? {
        guard let briefing else { return nil }

        let risks = meaningfulRisks(from: briefing.conflictsOrRisks)
        let isOverload = risks.contains(where: isOverloadRisk)
            || eventCount >= 7
        let hasOverlap = clarifyingConflict != nil
            || briefing.clarifyingConflict != nil
            || risks.contains { $0.localizedCaseInsensitiveContains("overlap") }
        let hasMultipleRisks = risks.count >= 2

        guard isOverload || hasOverlap || hasMultipleRisks else { return nil }

        let explanation = risks.first ?? briefing.topline
        var actions: [DayRescueAction] = []

        if clarifyingConflict != nil || briefing.clarifyingConflict != nil {
            actions.append(
                DayRescueAction(
                    id: "resolve-overlap",
                    label: "Pick must-attend meeting",
                    kind: .resolveOverlap
                )
            )
        }

        for (index, suggestion) in briefing.suggestedNextActions.prefix(3).enumerated() {
            guard actions.count < 3 else { break }
            actions.append(
                DayRescueAction(
                    id: "suggested-\(index)",
                    label: shortLabel(for: suggestion),
                    kind: .chatPrompt(chatPrompt(for: suggestion))
                )
            )
        }

        if actions.isEmpty {
            actions.append(
                DayRescueAction(
                    id: "rescue-chat",
                    label: "Help me rescue today",
                    kind: .chatPrompt("My day looks overloaded. Help me make a realistic plan without changing my calendar until I approve.")
                )
            )
        }

        return DayRescueState(
            explanation: explanation,
            conflicts: Array(risks.prefix(3)),
            recommendedPlan: Array(briefing.recommendedPlan.prefix(2)),
            actions: Array(actions.prefix(3))
        )
    }

    static func meaningfulRisks(from conflictsOrRisks: [String]) -> [String] {
        conflictsOrRisks.filter {
            !$0.localizedCaseInsensitiveContains("no major")
        }
    }

    private static func isOverloadRisk(_ risk: String) -> Bool {
        let lowered = risk.lowercased()
        return lowered.contains("overload")
            || lowered.contains("heavy")
            || lowered.contains("high-load")
    }

    private static func shortLabel(for suggestion: String) -> String {
        let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 44 { return trimmed }
        if let period = trimmed.prefix(44).lastIndex(of: ".") {
            return String(trimmed[..<period])
        }
        return String(trimmed.prefix(41)) + "…"
    }

    private static func chatPrompt(for suggestion: String) -> String {
        "Help me with today's plan: \(suggestion) Do not change my calendar until I approve."
    }
}
