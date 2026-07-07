import Combine
@preconcurrency import EventKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var section: AppSection = .chat
    @Published var entries: [ConversationEntry] = []
    @Published var events: [DayEvent] = []
    @Published var reminders: [DayReminder] = []
    @Published var calendarStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
    @Published var isLoadingCalendar = false
    @Published var isLoadingReminders = false
    @Published var isLoadingSchedules = false
    @Published var isSending = false
    @Published var isSyncingCalendar = false
    @Published var isSyncingReminders = false
    @Published var tankAvailable = false
    @Published var lastError: String?
    @Published var activity: [String] = []
    @Published var syncActivity: [SyncActivityEntry] = []
    @Published var briefing: DailyBriefing?
    @Published var approvals: [PendingApproval] = []
    @Published var proposals: [AgentProposal] = []
    @Published var schedules: [TankSchedule] = []
    @Published var isGeneratingBriefing = false
    @Published var isLoadingApprovals = false
    @Published var isLoadingProposals = false
    @Published var isSigningIn = false
    @Published var tankConnectStatus: String?
    @Published var tankAddress = TankConfiguration.savedAddress
    @Published var tankToken = TankConfiguration.savedToken
    @Published var approvalsFetchState: TankFetchState = .idle
    @Published var proposalsFetchState: TankFetchState = .idle
    @Published var schedulesFetchState: TankFetchState = .idle

    var appleUserID: String? { TankConfiguration.savedAppleUserID }

    private let calendar = CalendarService()
    private let tank = TankClient()
    private var refreshTask: Task<Void, Never>?

    var activeRoute: ProcessingRoute { tankAvailable ? .tank : .local }

    var hasCalendarAccess: Bool {
        calendarStatus == .fullAccess || calendarStatus == .authorized
    }

    var hasReminderReadAccess: Bool {
        reminderStatus == .fullAccess || reminderStatus == .authorized
    }

    var pendingDecisionCount: Int {
        approvals.filter { $0.status == "pending" }.count +
        proposals.filter { $0.status == "pending" }.count
    }

    deinit {
        refreshTask?.cancel()
    }

    func start() async {
        async let health: Void = refreshTankStatus()
        async let approvals: Void = loadApprovals()
        async let proposals: Void = loadProposals()
        async let schedulesTask: Void = loadSchedules()
        if hasCalendarAccess && hasReminderReadAccess {
            async let eventsTask: Void = loadToday()
            async let remindersTask: Void = loadReminders()
            _ = await (health, approvals, proposals, schedulesTask, eventsTask, remindersTask)
        } else if hasCalendarAccess {
            async let eventsTask: Void = loadToday()
            _ = await (health, approvals, proposals, schedulesTask, eventsTask)
        } else if hasReminderReadAccess {
            async let remindersTask: Void = loadReminders()
            _ = await (health, approvals, proposals, schedulesTask, remindersTask)
        } else {
            _ = await (health, approvals, proposals, schedulesTask)
        }
        if tankAvailable {
            if hasCalendarAccess {
                await syncCalendarToTank()
            }
            if hasReminderReadAccess {
                await syncRemindersToTank()
            }
        }
        startAutoRefresh()
    }

    func signInWithApple(userIdentifier: String, identityToken: String?) async {
        isSigningIn = true
        tankConnectStatus = "Connecting to Tank…"
        defer { isSigningIn = false }

        TankConfiguration.saveAppleUserID(userIdentifier)

        guard prepareTankAddressForAuth() else { return }

        let reachable = await tank.isReachable()
        if !reachable {
            tankConnectStatus = "Tank is not reachable at \(tankAddress)."
            lastError = "Could not reach Tank. If tank.local does not resolve, enter your Tank IP in Privacy (for example http://192.168.0.59:8000)."
            return
        }

        do {
            let response = try await tank.authWithApple(
                userIdentifier: userIdentifier,
                identityToken: identityToken
            )
            try TankConfiguration.save(address: tankAddress, token: response.deviceToken)
            tankToken = response.deviceToken
            tankAddress = TankConfiguration.savedAddress
            await refreshTankStatus()
            tankConnectStatus = tankAvailable
                ? "Connected to Tank"
                : "Token saved. Tank unavailable on this network."
            logActivity("Signed in with Apple and connected to Tank")
        } catch {
            tankConnectStatus = "Could not connect: \(error.localizedDescription)"
            if shouldMarkTankUnavailable(for: error) {
                lastError = "Tank is unreachable. Make sure you're on your home network and Tank is running."
            } else {
                lastError = "Tank didn't recognise this Apple ID. Make sure you've run the setup once at home."
            }
        }
    }

    func requestCalendarAccess() async {
        isLoadingCalendar = true
        defer { isLoadingCalendar = false }
        do {
            let granted = try await calendar.requestAccess()
            calendarStatus = EKEventStore.authorizationStatus(for: .event)
            if granted {
                logActivity("Calendar access approved")
                await loadToday()
                reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
                await syncCalendarToTank()
            } else {
                lastError = "Calendar access was not granted. NOBS still works as private chat."
            }
        } catch {
            lastError = "Calendar access could not be requested: \(error.localizedDescription)"
        }
    }

    func requestReminderAccess() async {
        isLoadingReminders = true
        defer { isLoadingReminders = false }
        do {
            let granted = try await calendar.requestReminderAccess()
            reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
            if granted {
                activity.insert("Reminders access approved", at: 0)
                await loadReminders()
                await syncRemindersToTank()
            } else {
                lastError = "Reminders access was not granted. Briefings will use calendar events only."
            }
        } catch {
            lastError = "Reminders access could not be requested: \(error.localizedDescription)"
        }
    }

    func loadToday() async {
        isLoadingCalendar = true
        defer { isLoadingCalendar = false }
        events = calendar.todayEvents()
        logActivity("Loaded \(events.count) calendar events locally")
    }

    func loadReminders() async {
        isLoadingReminders = true
        defer { isLoadingReminders = false }
        reminders = await calendar.todayReminders()
        activity.insert("Loaded \(reminders.count) reminder items locally", at: 0)
    }

    func loadSchedules() async {
        guard TankConfiguration.currentToken != nil else {
            schedulesFetchState = .unavailable
            return
        }
        isLoadingSchedules = true
        schedulesFetchState = .loading
        defer { isLoadingSchedules = false }
        do {
            schedules = try await tank.schedules()
            schedulesFetchState = tankAvailable ? .loaded : .unavailable
        } catch {
            schedulesFetchState = fetchState(for: error, resource: "schedules")
            if case .failed = schedulesFetchState {
                schedules = []
            }
        }
    }

    func refreshTankStatus() async {
        tankAvailable = await tank.isHealthy()
    }

    func applyTankPayload(from url: URL) {
        guard url.scheme?.lowercased() == "nobs",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        if let tankURL = components.queryItems?.first(where: { $0.name == "url" })?.value,
           !tankURL.isEmpty {
            tankAddress = tankURL
        } else if let device = components.queryItems?.first(where: { $0.name == "device" })?.value,
                  !device.isEmpty {
            tankAddress = "http://\(device):8000"
        }
        if let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
           !token.isEmpty {
            tankToken = token
        }
    }

    func saveTankConnection() async {
        guard let url = TankConfiguration.normalizedURL(from: tankAddress) else {
            lastError = "Enter a valid Tank address beginning with http:// or https://."
            return
        }
        let cleanToken = tankToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            lastError = "Enter the device token created during Tank setup."
            return
        }

        do {
            try TankConfiguration.save(address: url.absoluteString, token: cleanToken)
            tankAddress = url.absoluteString
            tankToken = cleanToken
            await refreshTankStatus()
            logActivity(tankAvailable ? "Tank connection verified" : "Tank connection saved; server unavailable")
            if !tankAvailable {
                lastError = "Connection saved, but Tank did not answer. NOBS will keep working locally."
            }
        } catch {
            lastError = "The Tank token could not be saved securely."
        }
    }

    func send(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isSending else { return }

        entries.append(ConversationEntry(role: .user, text: clean))
        isSending = true
        defer { isSending = false }

        if tankAvailable {
            do {
                let result = try await tank.chat(messages: entries)
                entries.append(
                    ConversationEntry(
                        role: .assistant,
                        text: result.message,
                        route: result.route,
                        receipt: result.receipt
                    )
                )
                logActivity("Tank answered a chat request")
                return
            } catch {
                if shouldMarkTankUnavailable(for: error) {
                    tankAvailable = false
                    lastError = "Tank went offline. This request stayed on your iPhone."
                } else {
                    lastError = "Tank couldn't answer that request. This request stayed on your iPhone."
                }
            }
        }

        // TODO(feature): Queue outbound messages while Tank is offline and replay them after reconnect.
        entries.append(localResponse(for: clean))
    }

    func generateBriefing() async {
        guard !isGeneratingBriefing else { return }
        isGeneratingBriefing = true
        defer { isGeneratingBriefing = false }
        let local = generateOnDeviceBriefing()
        briefing = local
        activity.insert("Created an on-device morning briefing", at: 0)

        guard tankAvailable else { return }
        do {
            briefing = try await tank.createBriefing(events: events, reminders: reminders)
            logActivity("Tank refined your morning briefing with synced context")
        } catch {
            if shouldMarkTankUnavailable(for: error) {
                tankAvailable = false
                lastError = "Tank went offline while creating the briefing. Your calendar remains available locally."
            } else {
                lastError = "Tank could not create the briefing. Your calendar remains available locally."
            }
        }
    }

    func loadApprovals() async {
        guard TankConfiguration.currentToken != nil else {
            approvalsFetchState = .unavailable
            return
        }
        isLoadingApprovals = true
        approvalsFetchState = .loading
        defer { isLoadingApprovals = false }
        do {
            approvals = try await tank.approvals()
            approvalsFetchState = tankAvailable ? .loaded : .unavailable
        } catch {
            approvalsFetchState = fetchState(for: error, resource: "approvals")
            if case .failed = approvalsFetchState {
                approvals = []
            }
        }
    }

    func decideApproval(_ approval: PendingApproval, decision: String) async {
        do {
            _ = try await tank.decideApproval(id: approval.id, decision: decision)
            logActivity("\(decision == "approve" ? "Approved" : "Denied") \(approval.toolName)")
            await loadApprovals()
        } catch {
            lastError = "Tank could not update that approval. It may already have been decided."
        }
    }

    func loadProposals() async {
        guard TankConfiguration.currentToken != nil else {
            proposalsFetchState = .unavailable
            return
        }
        isLoadingProposals = true
        proposalsFetchState = .loading
        defer { isLoadingProposals = false }
        do {
            proposals = try await tank.proposals()
            proposalsFetchState = tankAvailable ? .loaded : .unavailable
        } catch {
            proposalsFetchState = fetchState(for: error, resource: "proposals")
            if case .failed = proposalsFetchState {
                proposals = []
            }
        }
    }

    func decideProposal(_ proposal: AgentProposal, decision: String) async {
        do {
            _ = try await tank.decideProposal(id: proposal.id, decision: decision)
            logActivity("\(decision == "approve" ? "Approved" : "Dismissed") idea: \(proposal.title)")
            await loadProposals()
        } catch {
            lastError = "Tank could not update that proposal. It may already have been decided."
        }
    }

    func updateSchedule(_ schedule: TankSchedule, status: String) async {
        do {
            _ = try await tank.updateSchedule(id: schedule.id, status: status)
            activity.insert("Set schedule \(schedule.timeOfDay) to \(status)", at: 0)
            await loadSchedules()
        } catch {
            lastError = "Tank could not update that schedule right now."
        }
    }

    func syncCalendarToTank() async {
        guard tankAvailable, !isSyncingCalendar else { return }
        guard await ensureCalendarAccessForSync() else { return }
        isSyncingCalendar = true
        defer { isSyncingCalendar = false }

        do {
            let syncedEvents = calendar.syncEvents(daysAhead: 7)
            let formatter = ISO8601DateFormatter()
            let payload = syncedEvents.map {
                TankBriefingCalendarItem(
                    title: $0.title,
                    start: formatter.string(from: $0.start),
                    end: formatter.string(from: $0.end),
                    location: $0.location,
                    context: $0.context.rawValue
                )
            }
            try await tank.syncCalendar(events: payload)
            let receipt = PrivacyReceipt(
                used: ["\(payload.count) calendar event\(payload.count == 1 ? "" : "s") from EventKit"],
                processed: "Tank on your private network",
                shared: [],
                changed: ["Synced Tank calendar cache"]
            )
            syncActivity.insert(
                SyncActivityEntry(
                    title: "Calendar sync completed",
                    detail: "Uploaded \(payload.count) events from this iPhone",
                    route: .tank,
                    receipt: receipt
                ),
                at: 0
            )
            activity.insert("Synced \(payload.count) calendar events to Tank", at: 0)
        } catch {
            handleSyncFailure(kind: "calendar", error: error)
        }
    }

    func syncRemindersToTank() async {
        guard tankAvailable, !isSyncingReminders else { return }
        guard await ensureReminderAccessForSync() else { return }
        isSyncingReminders = true
        defer { isSyncingReminders = false }

        do {
            let syncedReminders = await calendar.openReminders(limit: 200)
            let isoFormatter = ISO8601DateFormatter()
            let payload = syncedReminders.map {
                TankBriefingReminderItem(
                    title: $0.title,
                    due: $0.due.map { isoFormatter.string(from: $0) },
                    context: $0.context.rawValue
                )
            }
            try await tank.syncReminders(reminders: payload)
            let receipt = PrivacyReceipt(
                used: ["\(payload.count) reminder\(payload.count == 1 ? "" : "s") from EventKit"],
                processed: "Tank on your private network",
                shared: [],
                changed: ["Synced Tank reminders cache"]
            )
            syncActivity.insert(
                SyncActivityEntry(
                    title: "Reminders sync completed",
                    detail: "Uploaded \(payload.count) reminders from this iPhone",
                    route: .tank,
                    receipt: receipt
                ),
                at: 0
            )
            activity.insert("Synced \(payload.count) reminders to Tank", at: 0)
        } catch {
            handleSyncFailure(kind: "reminders", error: error)
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                await self.refreshTankStatus()
                if self.tankAvailable {
                    await self.loadApprovals()
                    await self.loadProposals()
                    await self.loadSchedules()
                }
            }
        }
    }

    @discardableResult
    private func prepareTankAddressForAuth() -> Bool {
        guard let url = TankConfiguration.normalizedURL(from: tankAddress) else {
            tankConnectStatus = "Enter a valid Tank address in Privacy settings first."
            lastError = "Sign in needs a Tank address. Open Privacy and enter your Tank URL."
            return false
        }
        TankConfiguration.saveAddress(url.absoluteString)
        tankAddress = url.absoluteString
        return true
    }

    private func fetchState(for error: Error, resource: String) -> TankFetchState {
        if shouldMarkTankUnavailable(for: error) {
            tankAvailable = false
            return .unavailable
        }
        return .failed("Could not load \(resource) from Tank.")
    }

    private func handleSyncFailure(kind: String, error: Error) {
        let offline = shouldMarkTankUnavailable(for: error)
        if offline {
            tankAvailable = false
            lastError = "Tank is offline, so \(kind) sync stayed local."
        } else {
            lastError = "Tank could not sync \(kind). Your data stayed on this iPhone."
        }
        let receipt = PrivacyReceipt(
            used: ["\(kind) remained on this iPhone"],
            processed: "Local on this iPhone",
            shared: [],
            changed: []
        )
        syncActivity.insert(
            SyncActivityEntry(
                title: offline ? "\(kind.capitalized) sync stayed local" : "\(kind.capitalized) sync failed",
                detail: offline
                    ? "Tank was unavailable, so no \(kind) left this iPhone"
                    : "Tank returned an error; no \(kind) left this iPhone",
                route: .local,
                receipt: receipt
            ),
            at: 0
        )
    }

    private func ensureCalendarAccessForSync() async -> Bool {
        switch calendarStatus {
        case .fullAccess:
            return true
        case .notDetermined:
            await requestCalendarAccess()
            return hasCalendarAccess
        default:
            lastError = "Calendar access is required to sync events to Tank."
            return false
        }
    }

    private func ensureReminderAccessForSync() async -> Bool {
        switch reminderStatus {
        case .fullAccess:
            return true
        case .notDetermined:
            await requestReminderAccess()
            return hasReminderReadAccess
        default:
            lastError = "Reminders access is required to sync reminders to Tank."
            return false
        }
    }

    private func localResponse(for text: String) -> ConversationEntry {
        let normalized = text.lowercased()
        let response: String

        if normalized.contains("calendar") || normalized.contains("today") || normalized.contains("agenda") {
            if hasCalendarAccess {
                response = localAgendaSummary
            } else {
                response = "I can build that from your real calendar. Open Today and approve Calendar access when you're ready."
            }
        } else if normalized.contains("google") || normalized.contains("alexa") {
            response = "Google Home and Alexa unification is coming soon. Today I can help you design the routine without claiming it has run."
        } else {
            response = "Tank is unavailable, so I kept this request local. I can still help with your calendar and planning; open Privacy to see exactly what was used."
        }

        return ConversationEntry(
            role: .assistant,
            text: response,
            route: .local,
            receipt: .localOnly
        )
    }

    private func logActivity(_ message: String) {
        activity.insert(message, at: 0)
        if activity.count > 100 {
            activity.removeSubrange(100...)
        }
    }

    private func shouldMarkTankUnavailable(for error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return false
        }
        let code = URLError.Code(rawValue: nsError.code)

        switch code {
        case .notConnectedToInternet, .cannotConnectToHost, .networkConnectionLost:
            return true
        default:
            return false
        }
    }

    private var localAgendaSummary: String {
        guard !events.isEmpty else { return "Your calendar is clear for the rest of today." }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let first = events[0]
        let conflicts = events.filter(\.overlapsNext).count
        let conflictText = conflicts == 0 ? "I found no overlaps." : "I found \(conflicts) schedule conflict\(conflicts == 1 ? "" : "s")."
        return "You have \(events.count) event\(events.count == 1 ? "" : "s") today. First is \(first.title) at \(formatter.string(from: first.start)). \(conflictText)"
    }

    private func generateOnDeviceBriefing() -> DailyBriefing {
        let risks = detectBriefingRisks()
        let overload = risks.contains { $0.localizedCaseInsensitiveContains("overload") }
            || risks.contains { $0.localizedCaseInsensitiveContains("heavy") }
            || events.count >= 7
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let contextCounts = Dictionary(grouping: events, by: \.context).mapValues(\.count)

        let topline: String = {
            if events.isEmpty && reminders.isEmpty {
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
        let question = buildClarifyingQuestion(formatter: formatter)
        let actions = buildSuggestedActions(formatter: formatter, risks: risks)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return DailyBriefing(
            date: dateFormatter.string(from: .now),
            topline: topline,
            priorities: priorities,
            conflictsOrRisks: risks.isEmpty ? ["No major schedule collisions detected."] : risks,
            recommendedPlan: recommendedPlan,
            oneUsefulQuestion: question,
            suggestedNextActions: actions,
            generatedAt: ISO8601DateFormatter().string(from: .now),
            route: .local,
            privacyReceipt: PrivacyReceipt(
                used: [
                    "\(events.count) visible calendar event\(events.count == 1 ? "" : "s")",
                    "\(reminders.count) local reminder\(reminders.count == 1 ? "" : "s")",
                ],
                processed: "Local on this iPhone",
                shared: [],
                changed: []
            )
        )
    }

    private func buildPriorities(formatter: DateFormatter) -> [String] {
        let importantWords = ["deadline", "interview", "presentation", "review", "flight", "doctor", "launch"]
        let rankedEvents = events.sorted { lhs, rhs in
            let lhsImportant = importantWords.contains { lhs.title.lowercased().contains($0) }
            let rhsImportant = importantWords.contains { rhs.title.lowercased().contains($0) }
            if lhsImportant != rhsImportant { return lhsImportant }
            return lhs.start < rhs.start
        }
        var priorities = rankedEvents.prefix(4).map {
            "\(contextLabel($0.context)) · \($0.title) (\(formatter.string(from: $0.start)))"
        }
        if priorities.count < 3 {
            priorities.append(contentsOf: reminders.prefix(5 - priorities.count).map {
                "\(contextLabel($0.context)) · \($0.title)"
            })
        }
        if priorities.isEmpty {
            priorities.append("Protect one focused block for your highest-impact work.")
        }
        return Array(priorities.prefix(5))
    }

    private func detectBriefingRisks() -> [String] {
        guard !events.isEmpty else {
            return reminders.isEmpty ? [] : ["Your day has reminder commitments without fixed calendar blocks."]
        }
        var risks: [String] = []
        if events.count >= 7 {
            risks.append("Your calendar has \(events.count) events, which signals potential overload.")
        }
        var tightTransitions = 0
        var overlaps = 0
        var importantClusters = 0
        let importantWords = ["deadline", "interview", "presentation", "review", "flight", "doctor", "launch"]
        for (current, next) in zip(events, events.dropFirst()) {
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
        let morningEvents = events.filter {
            Calendar.current.component(.hour, from: $0.start) < 12
        }
        if morningEvents.count >= 4 {
            risks.append("Morning load is heavy with \(morningEvents.count) events before noon.")
        }
        return Array(risks.prefix(6))
    }

    private func buildRecommendedPlan(formatter: DateFormatter) -> [String] {
        var plan: [String] = []
        if let first = events.first {
            plan.append("Prepare for \(first.title) before \(formatter.string(from: first.start)).")
        }
        for event in events.prefix(3) {
            plan.append("Anchor \(contextLabel(event.context).lowercased()) focus around \(event.title) at \(formatter.string(from: event.start)).")
        }
        if !reminders.isEmpty {
            plan.append("Batch reminder follow-ups into one admin block between meetings.")
        }
        plan.append("Re-check afternoon priorities after lunch and defer low-impact work.")
        return Array(plan.prefix(6))
    }

    private func buildClarifyingQuestion(formatter: DateFormatter) -> String? {
        for (current, next) in zip(events, events.dropFirst()) where current.end > next.start {
            return "You have overlap between \(current.title) and \(next.title). Which one is must-attend?"
        }
        let hasAmbiguousReminders = reminders.count >= 3 && events.count >= 3
        if hasAmbiguousReminders {
            return "Which reminder is genuinely critical today so the rest can be deferred?"
        }
        return nil
    }

    private func buildSuggestedActions(formatter: DateFormatter, risks: [String]) -> [String] {
        var actions: [String] = []
        if let first = events.first {
            actions.append("Review prep for \(first.title) before \(formatter.string(from: first.start)).")
        }
        if !risks.isEmpty {
            actions.append("Draft a short conflict message for any meeting that can move.")
        }
        if let prepReminder = reminders.first {
            actions.append("Create a prep reminder block for \"\(prepReminder.title)\".")
        }
        actions.append("Re-check afternoon priorities after your second major commitment.")
        return Array(actions.prefix(4))
    }

    private func contextLabel(_ context: BriefingContextBucket) -> String {
        context.title
    }
}
