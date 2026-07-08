import Foundation

extension BriefingSnapshot {
    init(briefing: DailyBriefing, redactDetailsOnLockScreen: Bool = true) {
        let isEvening = briefing.kind == .evening
        let hasConflict: Bool
        let conflictSummary: String?

        if isEvening {
            let unfinished = briefing.conflictsOrRisks.filter {
                !$0.localizedCaseInsensitiveContains("nothing critical")
            }
            hasConflict = !unfinished.isEmpty
            conflictSummary = unfinished.first
        } else {
            hasConflict = !briefing.conflictsOrRisks.isEmpty
                && !briefing.conflictsOrRisks.contains(where: { $0.localizedCaseInsensitiveContains("no major") })
            conflictSummary = hasConflict ? briefing.conflictsOrRisks.first : nil
        }

        let priorities = Array(briefing.priorities.prefix(2))
        let tomorrowPreview = briefing.recommendedPlan.first(where: {
            $0.localizedCaseInsensitiveContains("tomorrow")
        }) ?? briefing.recommendedPlan.first

        self.init(
            date: briefing.date,
            kind: briefing.kind.rawValue,
            topline: briefing.topline,
            priorityCount: briefing.priorities.count,
            priorities: priorities,
            topPriority: briefing.priorities.first,
            hasConflict: hasConflict,
            conflictSummary: conflictSummary,
            tomorrowPreview: isEvening ? tomorrowPreview : nil,
            unfinishedCount: isEvening ? briefing.conflictsOrRisks.count : nil,
            route: briefing.route.rawValue,
            generatedAt: Self.parseGeneratedAt(briefing.generatedAt) ?? .now,
            redactDetailsOnLockScreen: redactDetailsOnLockScreen
        )
    }

    private static func parseGeneratedAt(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
