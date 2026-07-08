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
    @Published var isLoadingMemories = false
    @Published var isSending = false
    @Published var isSyncingCalendar = false
    @Published var isSyncingReminders = false
    @Published var tankAvailable = false
    @Published var lastError: String?
    @Published var activity: [String] = []
    @Published var syncActivity: [SyncActivityEntry] = []
    @Published var briefing: DailyBriefing?
    @Published var eveningBriefing: DailyBriefing?
    @Published var tomorrowEvents: [DayEvent] = []
    @Published var tomorrowReminders: [DayReminder] = []
    @Published var approvals: [PendingApproval] = []
    @Published var proposals: [AgentProposal] = []
    @Published var schedules: [TankSchedule] = []
    @Published var memories: [TankMemory] = []
    @Published var homeDevices: [HomeDevice] = []
    @Published var homeDevicesConfigured = false
    @Published var homeDevicesTruncated = false
    @Published var homeDevicesMessage: String?
    @Published var researchJobs: [ResearchJob] = []
    @Published var isLoadingHomeDevices = false
    @Published var isLoadingResearch = false
    @Published var isSubmittingResearch = false
    @Published var isGeneratingBriefing = false
    @Published var isGeneratingEveningBriefing = false
    @Published var isLoadingApprovals = false
    @Published var isLoadingProposals = false
    @Published var isSigningIn = false
    @Published var tankConnectStatus: String?
    @Published var tankAddress = TankConfiguration.savedAddress
    @Published var tankToken = TankConfiguration.savedToken
    @Published var tankLastConnectionError: String?
    @Published var tankSyncStatus: TankSyncStatus = .unknown
    @Published var discoveredTanks: [DiscoveredTank] = []
    @Published var pendingOfflineMessageCount = 0
    @Published var isReconnecting = false
    @Published var approvalsFetchState: TankFetchState = .idle
    @Published var proposalsFetchState: TankFetchState = .idle
    @Published var schedulesFetchState: TankFetchState = .idle
    @Published var memoriesFetchState: TankFetchState = .idle
    @Published var homeDevicesFetchState: TankFetchState = .idle
    @Published var researchFetchState: TankFetchState = .idle
    @Published var profile: UserProfile = UserProfile()
    @Published var pendingChatPrompt: String?
    @Published var clarifyingConflict: ClarifyingConflict?
    @Published var showConflictSheet = false
    @Published var highlightClarifyingQuestion = false
    @Published var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    var appleUserID: String? { TankConfiguration.savedAppleUserID }

    private let tank = TankClient()
    private let offlineQueue = OfflineMessageQueue()
    private let profileStore = UserProfileStore()
    private let focusContext = FocusContextService()

    private lazy var briefingCoordinator = BriefingCoordinator(model: self, tank: tank)
    private lazy var approvalsCoordinator = ApprovalsCoordinator(model: self, tank: tank)
    private lazy var memoryCoordinator = MemoryCoordinator(model: self, tank: tank)
    private lazy var homeCoordinator = HomeCoordinator(model: self, tank: tank)
    private lazy var researchCoordinator = ResearchCoordinator(model: self, tank: tank)
    private lazy var tankSync = TankSyncService(model: self, tank: tank)
    private lazy var localChatRouter = LocalChatRouter()

    var foundationModelsAvailable: Bool { FoundationModelsAdapter.isAvailable }
    var foundationModelsStatus: String {
        FoundationModelsAdapter.unavailabilityReason ?? "Available for local chat"
    }

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

    func start() async {
        profile = profileStore.load()
        pendingOfflineMessageCount = offlineQueue.load().count
        tankSync.updateTankSyncStatus()
        briefingCoordinator.restoreCachedBriefingIfNeeded()
        if clarifyingConflict == nil {
            clarifyingConflict = try? AppGroupStore.readJSON(
                ClarifyingConflict.self,
                from: AppGroupStore.clarifyingConflictFile
            )
        }
        notificationAuthorizationStatus = await NotificationScheduler.refreshAuthorizationStatus()
        async let health: Void = refreshTankStatus()
        async let approvals: Void = loadApprovals()
        async let proposals: Void = loadProposals()
        async let schedulesTask: Void = loadSchedules()
        async let memoriesTask: Void = loadMemories()
        async let researchTask: Void = loadResearchJobs()
        if hasCalendarAccess && hasReminderReadAccess {
            async let eventsTask: Void = loadToday()
            async let remindersTask: Void = loadReminders()
            _ = await (health, approvals, proposals, schedulesTask, memoriesTask, researchTask, eventsTask, remindersTask)
        } else if hasCalendarAccess {
            async let eventsTask: Void = loadToday()
            _ = await (health, approvals, proposals, schedulesTask, memoriesTask, researchTask, eventsTask)
        } else if hasReminderReadAccess {
            async let remindersTask: Void = loadReminders()
            _ = await (health, approvals, proposals, schedulesTask, memoriesTask, researchTask, remindersTask)
        } else {
            _ = await (health, approvals, proposals, schedulesTask, memoriesTask, researchTask)
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
        await tankSync.signInWithApple(userIdentifier: userIdentifier, identityToken: identityToken)
    }

    func requestCalendarAccess() async {
        await tankSync.requestCalendarAccess()
    }

    func requestReminderAccess() async {
        await tankSync.requestReminderAccess()
    }

    func loadToday() async { await tankSync.loadToday() }
    func loadReminders() async { await tankSync.loadReminders() }
    func loadSchedules() async { await approvalsCoordinator.loadSchedules() }
    func loadMemories() async { await memoryCoordinator.loadMemories() }
    func loadHomeDevices() async { await homeCoordinator.loadHomeDevices() }
    func loadResearchJobs() async { await researchCoordinator.loadResearchJobs() }
    func startResearch(topic: String) async { await researchCoordinator.startResearch(topic: topic) }
    func deleteMemory(_ memory: TankMemory) async { await memoryCoordinator.deleteMemory(memory) }
    func updateMemory(_ memory: TankMemory, content: String, category: String) async {
        await memoryCoordinator.updateMemory(memory, content: content, category: category)
    }

    func refreshTankStatus() async {
        if await tankSync.refreshTankStatus() {
            await replayQueuedMessages()
        }
    }

    func reconnectToTank() async {
        await tankSync.reconnectToTank()
        if tankAvailable {
            await replayQueuedMessages()
        }
    }

    func browseForTanks() async { await tankSync.browseForTanks() }

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
        case .tankPairing(let pairingURL):
            section = .privacy
            applyTankPayload(from: pairingURL)
            Task { await saveTankConnection() }
        }
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

    func saveTankConnection() async { await tankSync.saveTankConnection() }

    func send(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isSending else { return }

        let userEntry = ConversationEntry(role: .user, text: clean)
        entries.append(userEntry)
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
                if !result.receipt.changed.isEmpty {
                    await loadMemories()
                }
                logActivity("Tank answered a chat request")
                return
            } catch {
                let apiError = TankAPIError.map(error)
                if apiError.isConnectivityFailure {
                    tankAvailable = false
                    tankLastConnectionError = apiError.userFacingMessage
                    tankSync.updateTankSyncStatus()
                    lastError = "Tank went offline. This request will be sent when Tank reconnects."
                    queueOfflineMessage(userEntry)
                    entries.append(offlineAcknowledgement(pendingCount: pendingOfflineMessageCount))
                    return
                }
                lastError = apiError.userFacingMessage
            }
        } else if shouldQueueForOfflineDelivery() {
            queueOfflineMessage(userEntry)
            entries.append(offlineAcknowledgement(pendingCount: pendingOfflineMessageCount))
            return
        }

        let localResult = await localChatRouter.respond(
            to: clean,
            conversation: entries,
            context: localChatContext()
        )
        applyProfileMutations(localResult.profileMutations)
        entries.append(localResult.entry)
    }

    func generateBriefing() async { await briefingCoordinator.generateBriefing() }

    func generateEveningBriefing() async { await briefingCoordinator.generateEveningBriefing() }

    func loadTomorrow() async { await tankSync.loadTomorrow() }

    var showsEveningWrapUp: Bool {
        BriefingSchedule.eveningWrapUpHour(profile: profile) <= Calendar.current.component(.hour, from: Date())
    }

    func loadApprovals() async { await approvalsCoordinator.loadApprovals() }

    func decideApproval(_ approval: PendingApproval, decision: String) async {
        await approvalsCoordinator.decideApproval(approval, decision: decision)
    }

    func requestApprovalReversal(for approval: PendingApproval) {
        guard let reversal = ApprovalDetailFormatter.reversal(for: approval) else { return }
        section = .chat
        pendingChatPrompt = reversal.chatPrompt
        logActivity("Prepared undo path for \(approval.toolName)")
    }

    func showApprovalAuditTrail(for approval: PendingApproval) {
        section = .activity
        let runPrefix = String(approval.runId.prefix(8))
        logActivity("Reviewing audit trail for \(ApprovalDetailFormatter.humanToolTitle(approval.toolName)) (\(runPrefix))")
    }

    func loadProposals() async { await approvalsCoordinator.loadProposals() }

    func decideProposal(_ proposal: AgentProposal, decision: String) async {
        await approvalsCoordinator.decideProposal(proposal, decision: decision)
    }

    func updateSchedule(_ schedule: TankSchedule, status: String) async {
        await approvalsCoordinator.updateSchedule(schedule, status: status)
    }

    func syncCalendarToTank() async { await tankSync.syncCalendarToTank() }
    func syncRemindersToTank() async { await tankSync.syncRemindersToTank() }

    func logActivity(_ message: String) {
        activity.insert(message, at: 0)
        if activity.count > 100 {
            activity.removeSubrange(100...)
        }
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

        let today = briefingCoordinator.currentDayStamp()
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
        let risks = briefingCoordinator.detectBriefingRisks()
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

    private func persistProfile() {
        do {
            try profileStore.save(profile)
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

    private func startAutoRefresh() {
        tankSync.startAutoRefresh { [weak self] in
            guard let self else { return }
            async let approvals: Void = self.loadApprovals()
            async let proposals: Void = self.loadProposals()
            async let schedules: Void = self.loadSchedules()
            async let memories: Void = self.loadMemories()
            async let research: Void = self.loadResearchJobs()
            _ = await (approvals, proposals, schedules, memories, research)
        }
    }

    private func localChatContext() -> NOBSModelContext {
        NOBSModelContext(
            userName: profile.greetingName,
            hasCalendarAccess: hasCalendarAccess,
            agendaSummary: hasCalendarAccess ? localAgendaSummary : nil,
            tankAvailable: tankAvailable,
            shouldUseTomorrowFraming: focusContext.shouldUseTomorrowFraming(profile: profile)
        )
    }

    private func applyProfileMutations(_ mutations: [ProfileMutation]) {
        guard !mutations.isEmpty else { return }
        updateProfile { profile in
            for mutation in mutations {
                switch mutation {
                case .resetFocusPolicies:
                    profile.focusPolicies = []
                case .setFocusPolicies(let policies):
                    profile.focusPolicies = policies
                }
            }
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

    private func shouldQueueForOfflineDelivery() -> Bool {
        TankConfiguration.currentToken != nil
    }

    private func queueOfflineMessage(_ entry: ConversationEntry) {
        do {
            try offlineQueue.enqueue(QueuedChatMessage(id: entry.id, text: entry.text))
            pendingOfflineMessageCount = offlineQueue.load().count
            tankSync.updateTankSyncStatus()
        } catch {
            lastError = "Could not save your message for later delivery to Tank."
        }
    }

    private func offlineAcknowledgement(pendingCount: Int) -> ConversationEntry {
        let detail = pendingCount == 1
            ? "1 message queued for Tank"
            : "\(pendingCount) messages queued for Tank"
        return ConversationEntry(
            role: .assistant,
            text: "I'm keeping this on your iPhone for now. I'll send it to Tank automatically when you're back on your home network.",
            route: .local,
            receipt: PrivacyReceipt(
                used: ["text entered in this conversation"],
                processed: "Local on this iPhone",
                shared: [],
                changed: [detail]
            )
        )
    }

    private func replayQueuedMessages() async {
        let queued = offlineQueue.load()
        guard !queued.isEmpty, tankAvailable else { return }

        for item in queued {
            guard entries.contains(where: { $0.id == item.id }) else {
                try? offlineQueue.remove(id: item.id)
                continue
            }
            do {
                let result = try await tank.chat(messages: entries)
                let sentAt = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
                let replayReceipt = PrivacyReceipt(
                    used: result.receipt.used,
                    processed: result.receipt.processed,
                    shared: result.receipt.shared,
                    changed: result.receipt.changed + ["Sent to Tank at \(sentAt)"]
                )
                entries.append(
                    ConversationEntry(
                        role: .assistant,
                        text: result.message,
                        route: .tank,
                        receipt: replayReceipt
                    )
                )
                try offlineQueue.remove(id: item.id)
                pendingOfflineMessageCount = offlineQueue.load().count
                tankSync.updateTankSyncStatus()
                logActivity("Sent queued message to Tank at \(sentAt)")
            } catch {
                let apiError = TankAPIError.map(error)
                if apiError.isConnectivityFailure {
                    tankAvailable = false
                    tankLastConnectionError = apiError.userFacingMessage
                    tankSync.updateTankSyncStatus()
                }
                lastError = apiError.userFacingMessage
                break
            }
        }
    }
}
