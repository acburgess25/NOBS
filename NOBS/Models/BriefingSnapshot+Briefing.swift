import Foundation

extension BriefingSnapshot {
    init(
        briefing: DailyBriefing,
        profile: UserProfile,
        eveningHeadline: String? = nil,
        redactDetailsOnLockScreen: Bool = true
    ) {
        let responseLength = profile.accessibilityPreferences.responseLength
        let hasConflict = !briefing.conflictsOrRisks.isEmpty
            && !briefing.conflictsOrRisks.contains(where: { $0.localizedCaseInsensitiveContains("no major") })
        let conflictSummary: String? = hasConflict
            ? briefing.conflictsOrRisks.first
            : nil
        let priorities = Array(briefing.priorities.prefix(responseLength.maxWidgetPriorities))
        self.init(
            date: briefing.date,
            topline: briefing.topline,
            priorityCount: briefing.priorities.count,
            priorities: priorities,
            topPriority: briefing.priorities.first,
            hasConflict: hasConflict,
            conflictSummary: conflictSummary,
            route: briefing.route.rawValue,
            generatedAt: Self.parseGeneratedAt(briefing.generatedAt) ?? .now,
            redactDetailsOnLockScreen: redactDetailsOnLockScreen,
            responseLength: responseLength,
            eveningHeadline: eveningHeadline
        )
    }

    private static func parseGeneratedAt(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
