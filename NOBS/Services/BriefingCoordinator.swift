import Foundation
import UserNotifications

@MainActor
final class BriefingCoordinator {
    unowned let model: AppModel
    private let tank: TankClient
    private let briefingSnapshotWriter: BriefingSnapshotWriter
    private let focusContext: FocusContextService

    init(
        model: AppModel,
        tank: TankClient,
        briefingSnapshotWriter: BriefingSnapshotWriter = BriefingSnapshotWriter(),
        focusContext: FocusContextService = FocusContextService()
    ) {
        self.model = model
        self.tank = tank
        self.briefingSnapshotWriter = briefingSnapshotWriter
        self.focusContext = focusContext
    }

    func restoreCachedBriefingIfNeeded() {
        if model.briefing == nil,
           let cached: DailyBriefing = try? AppGroupStore.readJSON(
               DailyBriefing.self,
               from: AppGroupStore.latestBriefingFile
           ),
           cached.kind == .morning {
            model.briefing = cached
            model.clarifyingConflict = cached.clarifyingConflict
        }
        if model.eveningBriefing == nil,
           let cached: DailyBriefing = try? AppGroupStore.readJSON(
               DailyBriefing.self,
               from: AppGroupStore.latestEveningBriefingFile
           ),
           cached.kind == .evening {
            model.eveningBriefing = cached
        }
        persistBriefingSnapshot()
    }

    func persistBriefingSnapshot() {
        briefingSnapshotWriter.write(from: model.briefing, kind: .morning)
        briefingSnapshotWriter.write(from: model.eveningBriefing, kind: .evening)
        if let conflict = model.briefing?.clarifyingConflict ?? model.clarifyingConflict {
            model.clarifyingConflict = conflict
            try? AppGroupStore.writeJSON(conflict, to: AppGroupStore.clarifyingConflictFile)
        }
    }

    func generateBriefing() async {
        await generateBriefing(kind: .morning)
    }

    func generateEveningBriefing() async {
        await generateBriefing(kind: .evening)
    }

    private func generateBriefing(kind: BriefingKind) async {
        let isEvening = kind == .evening
        if isEvening {
            guard !model.isGeneratingEveningBriefing else { return }
            model.isGeneratingEveningBriefing = true
        } else {
            guard !model.isGeneratingBriefing else { return }
            model.isGeneratingBriefing = true
        }
        defer {
            if isEvening {
                model.isGeneratingEveningBriefing = false
            } else {
                model.isGeneratingBriefing = false
            }
        }

        if isEvening {
            await model.loadTomorrow()
        }

        let local = isEvening ? generateOnDeviceEveningBriefing() : generateOnDeviceBriefing()
        if isEvening {
            model.eveningBriefing = local
            model.logActivity("Created an on-device evening wrap-up")
        } else {
            model.briefing = local
            model.clarifyingConflict = local.clarifyingConflict
            model.logActivity("Created an on-device morning briefing")
        }
        persistBriefingSnapshot()

        if model.tankAvailable {
            do {
                let tankBriefing = try await tank.createBriefing(
                    kind: kind,
                    events: completedEventsForWrapUp(),
                    reminders: model.reminders,
                    tomorrowEvents: model.tomorrowEvents,
                    tomorrowReminders: model.tomorrowReminders
                )
                let merged = mergeTankBriefing(
                    tankBriefing,
                    preserving: isEvening ? nil : model.clarifyingConflict
                )
                if isEvening {
                    model.eveningBriefing = merged
                    model.logActivity("Tank refined your evening wrap-up with synced context")
                } else {
                    model.briefing = merged
                    model.clarifyingConflict = merged.clarifyingConflict
                    model.logActivity("Tank refined your morning briefing with synced context")
                }
                persistBriefingSnapshot()
            } catch {
                if TankSyncService.shouldMarkUnavailable(for: error) {
                    model.tankAvailable = false
                    model.lastError = isEvening
                        ? "Tank went offline while creating the wrap-up. Your local summary remains available."
                        : "Tank went offline while creating the briefing. Your calendar remains available locally."
                } else {
                    model.lastError = isEvening
                        ? "Tank could not create the evening wrap-up. Your local summary remains available."
                        : "Tank could not create the briefing. Your calendar remains available locally."
                }
            }
        }

        if isEvening {
            await scheduleEveningWrapUpNotificationIfNeeded()
        } else {
            maybeOfferFocusMismatchPrompt()
            await scheduleClarifyingNotificationIfNeeded()
        }
    }

    func detectBriefingRisks() -> [String] {
        guard !model.events.isEmpty else {
            return model.reminders.isEmpty
                ? []
                : ["Your day has reminder commitments without fixed calendar blocks."]
        }
        var risks: [String] = []
        if model.events.count >= 7 {
            risks.append("Your calendar has \(model.events.count) events, which signals potential overload.")
        }
        var tightTransitions = 0
        var overlaps = 0
        var importantClusters = 0
        let importantWords = ["deadline", "interview", "presentation", "review", "flight", "doctor", "launch"]
        for (current, next) in zip(model.events, model.events.dropFirst()) {
            if current.end > next.start {
                overlaps += 1
                continue
            }
            let gap = next.start.timeIntervalSince(current.end)
            if gap <= 600 {
                tightTransitions += 1
            }
            let currentImportant = importantWords.contains { current.title.lowercased().contains($0) }
            let nextImportant = importantWords.contains { next.title.lowercased().contains($0) }
            if currentImportant && nextImportant && gap <= 3600 {
                importantClusters += 1
            }
        }
        if overlaps > 0 {
            risks.append("\(overlaps) overlap\(overlaps == 1 ? "" : "s") need a clear attendance decision.")
        }
        if tightTransitions >= 2 {
            risks.append("\(tightTransitions) tight transitions under 10 minutes increase prep or travel risk.")
        }
        if importantClusters > 0 {
            risks.append("Important commitments are packed too closely for quality prep.")
        }
        let morningEvents = model.events.filter {
            Calendar.current.component(.hour, from: $0.start) < 12
        }
        if morningEvents.count >= 4 {
            risks.append("Morning load is heavy with \(morningEvents.count) events before noon.")
        }
        return Array(risks.prefix(6))
    }

    func currentDayStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func completedEventsForWrapUp() -> [DayEvent] {
        let now = Date()
        return model.events.filter { $0.end <= now || $0.start <= now }
    }

    private func unfinishedReminders() -> [DayReminder] {
        model.reminders
    }

    private func mergeTankBriefing(_ tank: DailyBriefing, preserving conflict: ClarifyingConflict?) -> DailyBriefing {
        DailyBriefing(
            date: tank.date,
            kind: tank.kind,
            topline: applyFocusToTopline(tank.topline),
            priorities: tank.priorities,
            conflictsOrRisks: tank.conflictsOrRisks,
            recommendedPlan: tank.recommendedPlan,
            oneUsefulQuestion: tank.oneUsefulQuestion ?? model.briefing?.oneUsefulQuestion,
            suggestedNextActions: tank.suggestedNextActions,
            generatedAt: tank.generatedAt,
            route: tank.route,
            privacyReceipt: tank.privacyReceipt,
            clarifyingConflict: conflict
        )
    }

    private func scheduleClarifyingNotificationIfNeeded() async {
        let snapshot = focusContext.currentSnapshot()
        let allows = focusContext.allowsProactiveNotifications(profile: model.profile, snapshot: snapshot)
        model.notificationAuthorizationStatus = await NotificationScheduler.refreshAuthorizationStatus()

        guard let question = model.briefing?.oneUsefulQuestion, !question.isEmpty else {
            model.highlightClarifyingQuestion = false
            await NotificationScheduler.cancelClarifyingNotification()
            return
        }

        if !allows {
            model.highlightClarifyingQuestion = true
            await NotificationScheduler.cancelClarifyingNotification()
            return
        }

        let scheduled = await NotificationScheduler.scheduleClarifyingNotification(
            question: question,
            conflict: model.clarifyingConflict ?? model.briefing?.clarifyingConflict,
            allowsSchedule: allows
        )
        model.highlightClarifyingQuestion = !scheduled && model.notificationAuthorizationStatus == .denied
        if scheduled {
            model.logActivity("Clarifying question surfaced")
        }
    }

    private func scheduleEveningWrapUpNotificationIfNeeded() async {
        let snapshot = focusContext.currentSnapshot()
        let allows = focusContext.allowsProactiveNotifications(profile: model.profile, snapshot: snapshot)
        model.notificationAuthorizationStatus = await NotificationScheduler.refreshAuthorizationStatus()

        guard let wrapUp = model.eveningBriefing else { return }

        if !allows {
            await NotificationScheduler.cancelEveningWrapUpNotification()
            return
        }

        let scheduled = await NotificationScheduler.scheduleEveningWrapUpNotification(
            topline: wrapUp.topline,
            allowsSchedule: allows
        )
        if scheduled {
            model.logActivity("Evening wrap-up notification scheduled")
        }
    }

    private func maybeOfferFocusMismatchPrompt() {
        let key = "nobs.focusMismatchOffered"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let snapshot = focusContext.currentSnapshot()
        guard snapshot.isFocusActive else { return }
        let personal = model.events.filter { $0.context == .personal }.count
        let business = model.events.filter { $0.context == .business }.count
        guard personal > business, personal >= 2 else { return }
        UserDefaults.standard.set(true, forKey: key)
        model.entries.append(
            ConversationEntry(
                role: .assistant,
                text: "You're in Focus mode but most of today's load looks personal. Want me to stay concise and work-focused anyway? Reply \"stay work focused\" or \"keep personal priority\".",
                route: .local,
                receipt: .localOnly
            )
        )
    }

    private func generateOnDeviceEveningBriefing() -> DailyBriefing {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let accomplishments = buildAccomplishments(formatter: formatter)
        let unfinished = buildUnfinishedCommitments(formatter: formatter)
        let tomorrowPlan = buildTomorrowPrep(formatter: formatter)
        let unfinishedCount = unfinished.count

        let topline: String = {
            let eventCount = accomplishments.count
            if eventCount == 0 && unfinishedCount == 0 {
                return "A calm day wraps up — tomorrow can stay light unless you choose otherwise."
            }
            if unfinishedCount == 0 {
                return "You moved through today's commitments. Nothing critical is left hanging."
            }
            if unfinishedCount == 1 {
                return "Solid progress today — one item can roll forward without guilt."
            }
            return "You made it through a full day. \(unfinishedCount) items can carry to tomorrow without finishing tonight."
        }()

        let question: String? = {
            if unfinishedCount >= 2 {
                return "Which carry-over item matters most tomorrow so the rest can wait?"
            }
            if model.tomorrowEvents.count >= 4 {
                return "Tomorrow looks packed — want to defer one lower-priority block now?"
            }
            return nil
        }()

        let actions = buildEveningActions(unfinishedCount: unfinishedCount)

        return DailyBriefing(
            date: currentDayStamp(),
            kind: .evening,
            topline: applyFocusToTopline(topline),
            priorities: accomplishments.isEmpty
                ? ["You protected space for rest and recovery today."]
                : accomplishments,
            conflictsOrRisks: unfinished.isEmpty
                ? ["Nothing critical needs to carry into tomorrow."]
                : unfinished,
            recommendedPlan: tomorrowPlan,
            oneUsefulQuestion: question,
            suggestedNextActions: actions,
            generatedAt: ISO8601DateFormatter().string(from: .now),
            route: .local,
            privacyReceipt: PrivacyReceipt(
                used: [
                    "\(completedEventsForWrapUp().count) completed calendar event\(completedEventsForWrapUp().count == 1 ? "" : "s")",
                    "\(model.reminders.count) open reminder\(model.reminders.count == 1 ? "" : "s")",
                    "\(model.tomorrowEvents.count) tomorrow event\(model.tomorrowEvents.count == 1 ? "" : "s")",
                ],
                processed: "Local on this iPhone",
                shared: [],
                changed: []
            )
        )
    }

    private func buildAccomplishments(formatter: DateFormatter) -> [String] {
        completedEventsForWrapUp().map {
            "\(contextLabel($0.context)) · \($0.title) (\(formatter.string(from: $0.start)))"
        }
    }

    private func buildUnfinishedCommitments(formatter: DateFormatter) -> [String] {
        var items = unfinishedReminders().map {
            var line = "\(contextLabel($0.context)) · \($0.title)"
            if let due = $0.due {
                line += " (due \(formatter.string(from: due)))"
            }
            return line + " — still open"
        }
        let now = Date()
        let upcoming = model.events.filter { $0.start > now }
        items.append(contentsOf: upcoming.prefix(3).map {
            "\(contextLabel($0.context)) · \($0.title) at \(formatter.string(from: $0.start)) — still ahead"
        })
        return Array(items.prefix(6))
    }

    private func buildTomorrowPrep(formatter: DateFormatter) -> [String] {
        var plan: [String] = []
        if let first = model.tomorrowEvents.sorted(by: { $0.start < $1.start }).first {
            plan.append("First up tomorrow: \(first.title) at \(formatter.string(from: first.start)).")
        }
        for event in model.tomorrowEvents.prefix(3) {
            plan.append("Block prep for \(contextLabel(event.context).lowercased()) · \(event.title).")
        }
        if !model.tomorrowReminders.isEmpty {
            plan.append("\(model.tomorrowReminders.count) reminder\(model.tomorrowReminders.count == 1 ? "" : "s") queued for tomorrow.")
        }
        if plan.isEmpty {
            plan.append("Tomorrow looks open — protect one block for what matters most.")
        }
        plan.append("Wind down without reopening today's unfinished list unless it helps.")
        return Array(plan.prefix(6))
    }

    private func buildEveningActions(unfinishedCount: Int) -> [String] {
        var actions: [String] = []
        if unfinishedCount > 0 {
            actions.append("Pick one carry-over item to tackle first tomorrow — the rest can wait.")
        }
        if let first = model.tomorrowEvents.sorted(by: { $0.start < $1.start }).first {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            actions.append("Set a gentle prep reminder for \(first.title) before bed.")
        }
        actions.append("Close the day — unfinished work does not need guilt tonight.")
        return Array(actions.prefix(4))
    }

    private func generateOnDeviceBriefing() -> DailyBriefing {
        let risks = detectBriefingRisks()
        let overload = risks.contains { $0.localizedCaseInsensitiveContains("overload") }
            || risks.contains { $0.localizedCaseInsensitiveContains("heavy") }
            || model.events.count >= 7
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let contextCounts = Dictionary(grouping: model.events, by: \.context).mapValues(\.count)
        let conflict = buildClarifyingConflict()

        let topline: String = {
            if model.events.isEmpty && model.reminders.isEmpty {
                return "This is a lighter day with room for focused work and recovery."
            }
            if overload {
                return "This is a high-load day; early pruning and sequencing will keep it realistic."
            }
            let personal = contextCounts[.personal, default: 0]
            let business = contextCounts[.business, default: 0]
            let shared = contextCounts[.shared, default: 0]
            return "This is a mixed day (\(business) business, \(personal) personal, \(shared) shared), and it should stay manageable with a clear order."
        }()

        let priorities = buildPriorities(formatter: formatter)
        let recommendedPlan = buildRecommendedPlan(formatter: formatter)
        let question = conflict?.question ?? buildClarifyingQuestion(formatter: formatter)
        let actions = buildSuggestedActions(formatter: formatter, risks: risks)

        return DailyBriefing(
            date: currentDayStamp(),
            kind: .morning,
            topline: applyFocusToTopline(topline),
            priorities: priorities,
            conflictsOrRisks: risks.isEmpty ? ["No major schedule collisions detected."] : risks,
            recommendedPlan: recommendedPlan,
            oneUsefulQuestion: question,
            suggestedNextActions: actions,
            generatedAt: ISO8601DateFormatter().string(from: .now),
            route: .local,
            privacyReceipt: PrivacyReceipt(
                used: [
                    "\(model.events.count) visible calendar event\(model.events.count == 1 ? "" : "s")",
                    "\(model.reminders.count) local reminder\(model.reminders.count == 1 ? "" : "s")",
                    focusContext.currentSnapshot().isFocusActive ? "Focus mode" : "standard mode",
                ],
                processed: "Local on this iPhone",
                shared: [],
                changed: []
            ),
            clarifyingConflict: conflict
        )
    }

    private func applyFocusToTopline(_ topline: String) -> String {
        if focusContext.effectiveResponseStyle(profile: model.profile) == .concise, topline.count > 120 {
            return String(topline.prefix(117)) + "..."
        }
        return topline
    }

    private func buildClarifyingConflict() -> ClarifyingConflict? {
        for (current, next) in zip(model.events, model.events.dropFirst()) where current.end > next.start {
            return ClarifyingConflict(
                question: "You have overlap between \(current.title) and \(next.title). Which one is must-attend?",
                optionA: .init(id: "a", label: current.title, eventID: current.id),
                optionB: .init(id: "b", label: next.title, eventID: next.id)
            )
        }
        return nil
    }

    private func buildPriorities(formatter: DateFormatter) -> [String] {
        let importantWords = ["deadline", "interview", "presentation", "review", "flight", "doctor", "launch"]
        let preferredContext = focusContext.preferredContext(profile: model.profile)
        let rankedEvents = model.events.sorted { lhs, rhs in
            if let preferredContext {
                if lhs.context == preferredContext && rhs.context != preferredContext { return true }
                if rhs.context == preferredContext && lhs.context != preferredContext { return false }
            }
            let lhsImportant = importantWords.contains { lhs.title.lowercased().contains($0) }
            let rhsImportant = importantWords.contains { rhs.title.lowercased().contains($0) }
            if lhsImportant != rhsImportant { return lhsImportant }
            return lhs.start < rhs.start
        }
        var priorities = rankedEvents.prefix(4).map {
            "\(contextLabel($0.context)) · \($0.title) (\(formatter.string(from: $0.start)))"
        }
        if priorities.count < 3 {
            priorities.append(contentsOf: model.reminders.prefix(5 - priorities.count).map {
                "\(contextLabel($0.context)) · \($0.title)"
            })
        }
        if priorities.isEmpty {
            priorities.append("Protect one focused block for your highest-impact work.")
        }
        return Array(priorities.prefix(5))
    }

    private func buildRecommendedPlan(formatter: DateFormatter) -> [String] {
        var plan: [String] = []
        if let first = model.events.first {
            plan.append("Prepare for \(first.title) before \(formatter.string(from: first.start)).")
        }
        for event in model.events.prefix(3) {
            plan.append("Anchor \(contextLabel(event.context).lowercased()) focus around \(event.title) at \(formatter.string(from: event.start)).")
        }
        if !model.reminders.isEmpty {
            plan.append("Batch reminder follow-ups into one admin block between meetings.")
        }
        plan.append("Re-check afternoon priorities after lunch and defer low-impact work.")
        return Array(plan.prefix(6))
    }

    private func buildClarifyingQuestion(formatter: DateFormatter) -> String? {
        for (current, next) in zip(model.events, model.events.dropFirst()) where current.end > next.start {
            return "You have overlap between \(current.title) and \(next.title). Which one is must-attend?"
        }
        let hasAmbiguousReminders = model.reminders.count >= 3 && model.events.count >= 3
        if hasAmbiguousReminders {
            return "Which reminder is genuinely critical today so the rest can be deferred?"
        }
        return nil
    }

    private func buildSuggestedActions(formatter: DateFormatter, risks: [String]) -> [String] {
        var actions: [String] = []
        if let first = model.events.first {
            actions.append("Review prep for \(first.title) before \(formatter.string(from: first.start)).")
        }
        if !risks.isEmpty {
            actions.append("Draft a short conflict message for any meeting that can move.")
        }
        if let prepReminder = model.reminders.first {
            actions.append("Create a prep reminder block for \"\(prepReminder.title)\".")
        }
        actions.append("Re-check afternoon priorities after your second major commitment.")
        return Array(actions.prefix(4))
    }

    private func contextLabel(_ context: BriefingContextBucket) -> String {
        context.title
    }
}
