import Foundation

extension BriefingSnapshot {
    init(
        briefing: DailyBriefing,
        profile: UserProfile,
        eventCount: Int = 0,
        eveningHeadline: String? = nil,
        redactDetailsOnLockScreen: Bool = true
    ) {
        let responseLength = profile.accessibilityPreferences.responseLength
        let hasConflict = !briefing.conflictsOrRisks.isEmpty
            && !briefing.conflictsOrRisks.contains(where: { $0.localizedCaseInsensitiveContains("no major") })
        let conflictSummary: String? = hasConflict
            ? briefing.conflictsOrRisks.first
            : nil
        let rescue = BriefingCoordinator.dayRescueState(
            from: briefing,
            eventCount: eventCount,
            clarifyingConflict: briefing.clarifyingConflict
        )
        let priorities = Array(briefing.priorities.prefix(responseLength.maxWidgetPriorities))
        self.init(
            date: briefing.date,
            topline: briefing.topline,
            priorityCount: briefing.priorities.count,
            priorities: priorities,
            topPriority: briefing.priorities.first,
            hasConflict: hasConflict,
            conflictSummary: conflictSummary,
            needsDayRescue: rescue != nil,
            rescueSummary: rescue?.explanation,
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
