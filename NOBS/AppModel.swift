import Combine
@preconcurrency import EventKit
import Foundation
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    /// Set from the running app so App Intents can reach live state. Intents fall back to App Group cache when nil.
    static weak var shared: AppModel?

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
    @Published var profile: UserProfile = UserProfile()
    @Published var pendingChatPrompt: String?
    @Published var clarifyingConflict: ClarifyingConflict?
    @Published var showConflictSheet = false
    @Published var highlightClarifyingQuestion = false
    @Published var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var externalConfigFolderName: String? = ExternalConfigSync.linkedFolderName
    @Published var externalConfigLastSyncAt: Date?
    @Published var externalConfigStatus: String?

    var appleUserID: String? { TankConfiguration.savedAppleUserID }

    private let calendar = CalendarService()
    private let tank = TankClient()
    private let profileStore = UserProfileStore()
    private let briefingSnapshotWriter = BriefingSnapshotWriter()
    private let focusContext = FocusContextService()
    private let approvalActivityManager = ApprovalActivityManager()
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

    var needsOnboarding: Bool {
        !profile.isOnboardingComplete
    }

    var personalizedDayPartGreeting: String {
        let part: String
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: part = "morning"
        case 12..<18: part = "afternoon"
        default: part = "evening"
        }
        if let name = profile.greetingName {
            return "Good \(part), \(name)."
        }
        return "Good \(part)."
    }

    deinit {
        refreshTask?.cancel()
    }

    func start() async {
        profile = profileStore.load()
        if briefing == nil, let cached: DailyBriefing = try? AppGroupStore.readJSON(DailyBriefing.self, from: AppGroupStore.latestBriefingFile) {
            briefing = cached
            clarifyingConflict = cached.clarifyingConflict
            persistBriefingSnapshot()
        }
        if clarifyingConflict == nil {
            clarifyingConflict = try? AppGroupStore.readJSON(ClarifyingConflict.self, from: AppGroupStore.clarifyingConflictFile)
        }
        notificationAuthorizationStatus = await NotificationScheduler.refreshAuthorizationStatus()
        approvalActivityManager.reconnectIfNeeded()
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
        await syncExternalConfigFromFolder()
    }

    func linkExternalConfigFolder(_ url: URL) async {
        do {
            try ExternalConfigSync.saveFolderBookmark(url)
            externalConfigFolderName = url.lastPathComponent
            externalConfigStatus = "Linked \(url.lastPathComponent)."
            await syncExternalConfigFromFolder()
        } catch {
            lastError = "Could not link config folder."
            externalConfigStatus = "Link failed."
        }
    }

    func unlinkExternalConfigFolder() {
        ExternalConfigSync.clearFolderBookmark()
        externalConfigFolderName = nil
        externalConfigStatus = "Config folder unlinked."
    }

    func syncExternalConfigFromFolder() async {
        guard ExternalConfigSync.hasLinkedFolder else { return }
        let syncResult = await ExternalConfigSync.sync(profile: profile, tankAddress: tankAddress)
        let result = syncResult.result
        if result.appliedProfile {
            profile = syncResult.profile
            persistProfile()
        }
        if result.appliedTankAddress {
            tankAddress = syncResult.tankAddress
        }
        if result.appliedProfile || result.appliedTankAddress {
            externalConfigLastSyncAt = Date()
        }
        externalConfigStatus = result.summary
        if result.appliedTankAddress, TankConfiguration.currentToken != nil {
            await refreshTankStatus()
        }
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
            lastError = "Could not reach Tank. If tank.local does not resolve, enter your Tank IP in Privacy (for example http://192.168.1.100:8000)."
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
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        if let tankURL = components.queryItems?.first(where: { $0.name == "url" })?.value {
            tankAddress = tankURL
        } else if let device = components.queryItems?.first(where: { $0.name == "device" })?.value {
            tankAddress = "http://\(device):8000"
        }
        if let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
            tankToken = token
        }
    }

    func handleDeepLink(_ url: URL) {
        guard let destination = DeepLinkRouter.destination(for: url) else { return }
        switch destination {
        case .today:
            section = .today
        case .chat(let prompt):
            section = .chat
            if let prompt, !prompt.isEmpty {
                pendingChatPrompt = prompt
            }
        case .privacy:
            section = .privacy
        case .conflict:
            section = .today
            if clarifyingConflict != nil {
                showConflictSheet = true
            } else {
                pendingChatPrompt = "Help me resolve today's schedule conflict."
                section = .chat
            }
        case .approvals(let id, let action):
            section = .approvals
            if let id, let action {
                Task { await decideApprovalFromDeepLink(id: id, decision: action) }
            }
        case .tankPairing(let pairingURL):
            section = .privacy
            applyTankPayload(from: pairingURL)
            Task { await saveTankConnection() }
        }
    }

    /// Handles Approve/Deny taps from the Live Activity or its notification.
    /// Reuses `decideApproval` so the decision still goes through the same
    /// atomic, audited Tank approval route as the in-app button.
    private func decideApprovalFromDeepLink(id: String, decision: String) async {
        if approvals.isEmpty {
            await loadApprovals()
        }
        guard let approval = approvals.first(where: { $0.id == id && $0.status == "pending" }) else {
            lastError = "That approval is no longer pending."
            return
        }
        await decideApproval(approval, decision: decision)
    }

    func handleDeepLink(chatPrompt: String) {
        section = .chat
        if !chatPrompt.isEmpty {
            pendingChatPrompt = chatPrompt
        }
    }

    func resolveConflict(choosing option: ClarifyingConflict.Option) {
        showConflictSheet = false
        handleDeepLink(chatPrompt: "Help me keep \(option.label) as must-attend for today's overlap.")
    }

    func consumePendingChatPrompt() -> String? {
        defer { pendingChatPrompt = nil }
        return pendingChatPrompt
    }

    func updateProfile(_ update: (inout UserProfile) -> Void) {
        update(&profile)
        persistProfile()
    }

    func completeOnboarding() {
        updateProfile { profile in
            profile.onboardingCompletedAt = Date()
        }
        seedPostOnboardingChatIfNeeded()
    }

    var shouldShowEveningWrapUp: Bool {
        Calendar.current.component(.hour, from: Date()) >= 17
    }

    func generateEveningWrapUp() -> EveningWrapUp {
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let completed = events.filter { $0.end <= now }.map {
            "\($0.title) (\(formatter.string(from: $0.start)))"
        }
        var stillOpen: [String] = events.filter { $0.start > now }.map {
            "\($0.title) at \(formatter.string(from: $0.start))"
        }
        stillOpen.append(contentsOf: reminders.prefix(4).map(\.title))

        if stillOpen.isEmpty, let actions = briefing?.suggestedNextActions.prefix(2) {
            stillOpen = Array(actions)
        }

        let headline: String = {
            if completed.isEmpty && stillOpen.isEmpty {
                return "You made it through the day. Tomorrow can start fresh."
            }
            if completed.count >= 3 {
                return "You moved \(completed.count) commitments forward today."
            }
            if !stillOpen.isEmpty {
                return "A few items can wait until tomorrow — no guilt required."
            }
            return "Today is winding down. Here's an honest snapshot."
        }()

        let gentleClose = briefing?.recommendedPlan.first
            ?? "Rest counts. I'll have a morning briefing ready when you are."

        return EveningWrapUp(
            headline: headline,
            completedItems: Array(completed.prefix(5)),
            stillOpen: Array(stillOpen.prefix(5)),
            gentleClose: gentleClose
        )
    }

    var chatSuggestions: [String] {
        var options: [String] = []
        if shouldShowEveningWrapUp {
            options.append("How did today go?")
        }
        options.append(contentsOf: [
            "What's on my calendar?",
            "Help me prioritize today",
            tankAvailable ? "Is Tank online?" : "Open my day plan",
        ])
        let limit = profile.accessibilityPreferences.responseLength.maxChatSuggestions
        return Array(options.prefix(limit))
    }

    func formattedAssistantText(_ text: String) -> String {
        let limit = profile.accessibilityPreferences.responseLength.maxCharacters
        guard text.count > limit else { return text }
        let prefix = String(text.prefix(limit))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "… Open Today for more."
        }
        return prefix + "…"
    }

    private func persistProfile() {
        do {
            try profileStore.save(profile)
            if briefing != nil {
                persistBriefingSnapshot()
            }
        } catch {
            lastError = "Your preferences could not be saved on this iPhone."
        }
    }

    private func seedPostOnboardingChatIfNeeded() {
        guard entries.isEmpty else { return }
        if let problem = profile.immediateProblem?.trimmingCharacters(in: .whitespacesAndNewlines), !problem.isEmpty {
            entries.append(
                ConversationEntry(
                    role: .assistant,
                    text: "You mentioned \"\(problem).\" Want me to draft a plan? Open Today when you're ready to connect your calendar — I'll ask only when it's useful.",
                    route: .local,
                    receipt: .localOnly
                )
            )
        }
    }

    private func persistBriefingSnapshot() {
        let eveningHeadline = shouldShowEveningWrapUp ? generateEveningWrapUp().headline : nil
        briefingSnapshotWriter.write(
            from: briefing,
            profile: profile,
            eveningHeadline: eveningHeadline
        )
        if let conflict = briefing?.clarifyingConflict ?? clarifyingConflict {
            clarifyingConflict = conflict
            try? AppGroupStore.writeJSON(conflict, to: AppGroupStore.clarifyingConflictFile)
        }
    }

    private func scheduleClarifyingNotificationIfNeeded() async {
        let snapshot = focusContext.currentSnapshot()
        let allows = focusContext.allowsProactiveNotifications(profile: profile, snapshot: snapshot)
        notificationAuthorizationStatus = await NotificationScheduler.refreshAuthorizationStatus()

        guard let question = briefing?.oneUsefulQuestion, !question.isEmpty else {
            highlightClarifyingQuestion = false
            await NotificationScheduler.cancelClarifyingNotification()
            return
        }

        if !allows {
            highlightClarifyingQuestion = true
            await NotificationScheduler.cancelClarifyingNotification()
            return
        }

        let scheduled = await NotificationScheduler.scheduleClarifyingNotification(
            question: question,
            conflict: clarifyingConflict ?? briefing?.clarifyingConflict,
            allowsSchedule: allows
        )
        highlightClarifyingQuestion = !scheduled && notificationAuthorizationStatus == .denied
        if scheduled {
            logActivity("Clarifying question surfaced")
        }
    }

    private func maybeOfferFocusMismatchPrompt() {
        let key = "nobs.focusMismatchOffered"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let snapshot = focusContext.currentSnapshot()
        guard snapshot.isFocusActive else { return }
        let personal = events.filter { $0.context == .personal }.count
        let business = events.filter { $0.context == .business }.count
        guard personal > business, personal >= 2 else { return }
        UserDefaults.standard.set(true, forKey: key)
        entries.append(
            ConversationEntry(
                role: .assistant,
                text: "You're in Focus mode but most of today's load looks personal. Want me to stay concise and work-focused anyway? Reply \"stay work focused\" or \"keep personal priority\".",
                route: .local,
                receipt: .localOnly
            )
        )
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
                        text: formattedAssistantText(result.message),
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
        clarifyingConflict = local.clarifyingConflict
        persistBriefingSnapshot()
        activity.insert("Created an on-device morning briefing", at: 0)

        if tankAvailable {
            do {
                let tankBriefing = try await tank.createBriefing(events: events, reminders: reminders)
                briefing = mergeTankBriefing(tankBriefing, preserving: local.clarifyingConflict)
                persistBriefingSnapshot()
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

        maybeOfferFocusMismatchPrompt()
        await scheduleClarifyingNotificationIfNeeded()
    }

    private func mergeTankBriefing(_ tank: DailyBriefing, preserving conflict: ClarifyingConflict?) -> DailyBriefing {
        DailyBriefing(
            date: tank.date,
            topline: applyFocusToTopline(tank.topline),
            priorities: tank.priorities,
            conflictsOrRisks: tank.conflictsOrRisks,
            recommendedPlan: tank.recommendedPlan,
            oneUsefulQuestion: tank.oneUsefulQuestion ?? briefing?.oneUsefulQuestion,
            suggestedNextActions: tank.suggestedNextActions,
            generatedAt: tank.generatedAt,
            route: tank.route,
            privacyReceipt: tank.privacyReceipt,
            clarifyingConflict: conflict
        )
    }

    func loadApprovals() async {
        guard TankConfiguration.currentToken != nil else {
            approvalsFetchState = .unavailable
            await approvalActivityManager.endActivity()
            return
        }
        isLoadingApprovals = true
        approvalsFetchState = .loading
        defer { isLoadingApprovals = false }
        do {
            approvals = try await tank.approvals()
            approvalsFetchState = tankAvailable ? .loaded : .unavailable
            await approvalActivityManager.sync(with: approvals)
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

        if normalized.contains("reset focus") {
            updateProfile { $0.focusPolicies = [] }
            response = "Focus behavior reset. I'll use standard planning unless you teach me another preference."
        } else if normalized.contains("stay work focused") {
            updateProfile { profile in
                profile.focusPolicies = [
                    FocusPolicy(
                        focusIdentifier: FocusContextService.systemFocusIdentifier,
                        displayName: "Focus",
                        responseStyle: .concise,
                        allowProactiveNotifications: false,
                        preferredContext: .business
                    ),
                ]
            }
            response = "Got it — I'll stay concise and work-focused while Focus is on."
        } else if normalized.contains("keep personal priority") {
            updateProfile { profile in
                profile.focusPolicies = [
                    FocusPolicy(
                        focusIdentifier: FocusContextService.systemFocusIdentifier,
                        displayName: "Focus",
                        responseStyle: .standard,
                        allowProactiveNotifications: false,
                        preferredContext: .personal
                    ),
                ]
            }
            response = "Understood — I'll keep personal priorities visible even during Focus."
        } else if normalized.contains("evening") || normalized.contains("how did today") || normalized.contains("wrap up") {
            if shouldShowEveningWrapUp {
                let wrapUp = generateEveningWrapUp()
                response = [wrapUp.headline, wrapUp.gentleClose].joined(separator: " ")
            } else {
                response = "Evening wrap-up appears on Today after 5pm with an honest snapshot of your day."
            }
        } else if normalized.contains("calendar") || normalized.contains("today") || normalized.contains("agenda") {
            if hasCalendarAccess {
                response = localAgendaSummary
            } else {
                response = "I can build that from your real calendar. Open Today and approve Calendar access when you're ready."
            }
        } else if normalized.contains("google") || normalized.contains("alexa") {
            response = "Google Home and Alexa unification is coming soon. Today I can help you design the routine without claiming it has run."
        } else if focusContext.shouldUseTomorrowFraming(profile: profile) {
            response = "Tank is unavailable, so I kept this local. We can pick this up tomorrow — open Today if you want to preview the day."
        } else {
            response = "Tank is unavailable, so I kept this request local. I can still help with your calendar and planning; open Privacy to see exactly what was used."
        }

        return ConversationEntry(
            role: .assistant,
            text: formattedAssistantText(response),
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
        let conflict = buildClarifyingConflict()

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
        let question = conflict?.question ?? buildClarifyingQuestion(formatter: formatter)
        let actions = buildSuggestedActions(formatter: formatter, risks: risks)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return DailyBriefing(
            date: dateFormatter.string(from: .now),
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
                    "\(events.count) visible calendar event\(events.count == 1 ? "" : "s")",
                    "\(reminders.count) local reminder\(reminders.count == 1 ? "" : "s")",
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
        if focusContext.effectiveResponseStyle(profile: profile) == .concise, topline.count > 120 {
            return String(topline.prefix(117)) + "..."
        }
        return topline
    }

    private func buildClarifyingConflict() -> ClarifyingConflict? {
        for (current, next) in zip(events, events.dropFirst()) where current.end > next.start {
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
        let preferredContext = focusContext.preferredContext(profile: profile)
        let rankedEvents = events.sorted { lhs, rhs in
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

    func prepareDayIntentDialog() async -> String {
        if needsOnboarding {
            return "Finish NOBS onboarding in the app first."
        }
        if !hasCalendarAccess {
            if calendarStatus == .notDetermined {
                await requestCalendarAccess()
            }
            if !hasCalendarAccess {
                return "I need Calendar access to build a real plan. Open Today in NOBS when you're ready."
            }
        }

        await refreshTankStatus()
        await loadToday()
        if hasReminderReadAccess {
            await loadReminders()
        }

        let today = currentDayStamp()
        if briefing?.date != today {
            await generateBriefing()
        } else if briefing == nil {
            await generateBriefing()
        }

        guard let briefing else {
            return "I couldn't build a briefing right now. Open Today in NOBS."
        }
        return AppIntentSupport.formatPrepareDay(briefing)
    }

    func explainScheduleIntentDialog() async -> String {
        if needsOnboarding {
            return "Finish NOBS onboarding in the app first."
        }

        if let briefing {
            return AppIntentSupport.formatExplainSchedule(briefing)
        }

        if !hasCalendarAccess {
            return "Open Today in NOBS and connect your calendar to scan for unrealistic days."
        }

        await loadToday()
        let risks = detectBriefingRisks()
        if risks.isEmpty {
            return "Nothing unrealistic stood out from today's calendar. Processed on this iPhone."
        }
        return "\(risks.prefix(2).joined(separator: " ")) Processed on this iPhone."
    }

    func askNOBSIntentDialog(prompt: String) async -> String {
        if needsOnboarding {
            return "Finish NOBS onboarding in the app first."
        }

        section = .chat
        pendingChatPrompt = prompt

        await refreshTankStatus()
        if tankAvailable {
            await send(prompt)
            if let last = entries.last(where: { $0.role == .assistant }) {
                let route = last.route.map { AppIntentSupport.routeLabel($0) } ?? "Processed on this iPhone"
                return "\(last.text) \(route)."
            }
        }

        return "Opened NOBS with your question."
    }

    func showPrivacyReceiptIntentDialog() async -> String {
        section = .privacy

        if let receipt = briefing?.privacyReceipt {
            return AppIntentSupport.formatReceipt(receipt)
        }

        if let receipt = entries.last(where: { $0.receipt != nil })?.receipt {
            return AppIntentSupport.formatReceipt(receipt)
        }

        return "Open NOBS Privacy to see what was used and where it was processed."
    }

    private func currentDayStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
