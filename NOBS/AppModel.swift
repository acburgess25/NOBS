import AnyCodable
import Combine
@preconcurrency import EventKit
import Foundation
@preconcurrency import KeychainAccess

enum ProcessingRoute: String, Codable, Sendable {
    case local = "Local"
    case tank = "Tank"
    case cloud = "NOBScloud"
}

struct PrivacyReceipt: Codable, Hashable, Sendable {
    let used: [String]
    let processed: String
    let shared: [String]
    let changed: [String]

    static let localOnly = PrivacyReceipt(
        used: ["text entered in this conversation"],
        processed: "Local on this iPhone",
        shared: [],
        changed: []
    )
}

struct ConversationEntry: Identifiable, Codable, Sendable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String
    let route: ProcessingRoute?
    let receipt: PrivacyReceipt?

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        route: ProcessingRoute? = nil,
        receipt: PrivacyReceipt? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.route = route
        self.receipt = receipt
    }
}

struct DayEvent: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let calendarName: String
    let context: BriefingContextBucket

    var overlapsNext: Bool = false
}

enum BriefingContextBucket: String, Codable, CaseIterable {
    case personal
    case business
    case shared

    var title: String { rawValue.capitalized }
}

struct DayReminder: Identifiable, Hashable {
    let id: String
    let title: String
    let due: Date?
    let calendarName: String
    let context: BriefingContextBucket
}

struct DailyBriefing: Codable, Sendable {
    let date: String
    let topline: String
    let priorities: [String]
    let conflictsOrRisks: [String]
    let recommendedPlan: [String]
    let oneUsefulQuestion: String?
    let suggestedNextActions: [String]
    let generatedAt: String
    let route: ProcessingRoute
    let privacyReceipt: PrivacyReceipt

    enum CodingKeys: String, CodingKey {
        case date, topline, priorities, route
        case conflictsOrRisks = "conflicts_or_risks"
        case recommendedPlan = "recommended_plan"
        case oneUsefulQuestion = "one_useful_question"
        case suggestedNextActions = "suggested_next_actions"
        case generatedAt = "generated_at"
        case privacyReceipt = "privacy_receipt"
    }
}

struct PendingApproval: Identifiable, Codable, @unchecked Sendable {
    let id: String
    let runId: String
    let toolName: String
    let arguments: [String: AnyCodable]
    let risk: String
    let reason: String
    let status: String
    let createdAt: String
    let decidedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, risk, reason, status, arguments
        case runId = "run_id"
        case toolName = "tool_name"
        case createdAt = "created_at"
        case decidedAt = "decided_at"
    }
}

struct AgentProposal: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let description: String
    let proposalType: String
    let status: String
    let createdAt: String
    let decidedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, status
        case proposalType = "proposal_type"
        case createdAt = "created_at"
        case decidedAt = "decided_at"
    }
}

extension AnyCodable {
    var displayString: String {
        switch value {
        case let value as String:
            return value
        case let value as Bool:
            return value ? "true" : "false"
        case let value as Int:
            return "\(value)"
        case let value as Double:
            return "\(value)"
        default:
            return String(describing: value)
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case today = "Today"
    case approvals = "Approvals"
    case memory = "Memory"
    case activity = "Activity"
    case home = "Home"
    case privacy = "Privacy"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .chat: "message"
        case .today: "sun.max"
        case .approvals: "checkmark.shield"
        case .memory: "brain"
        case .activity: "clock.arrow.circlepath"
        case .home: "house"
        case .privacy: "hand.raised"
        }
    }
}

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
    @Published var isSending = false
    @Published var tankAvailable = false
    @Published var lastError: String?
    @Published var activity: [String] = []
    @Published var briefing: DailyBriefing?
    @Published var approvals: [PendingApproval] = []
    @Published var proposals: [AgentProposal] = []
    @Published var isGeneratingBriefing = false
    @Published var isLoadingApprovals = false
    @Published var isLoadingProposals = false
    @Published var isSigningIn = false
    @Published var tankConnectStatus: String?
    @Published var tankAddress = TankConfiguration.savedAddress
    @Published var tankToken = TankConfiguration.savedToken

    /// The Apple user identifier stored in keychain after Sign in with Apple.
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

    /// Total count of items needing a decision (shown as badge).
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
        if hasCalendarAccess && hasReminderReadAccess {
            async let eventsTask: Void = loadToday()
            async let remindersTask: Void = loadReminders()
            _ = await (health, approvals, proposals, eventsTask, remindersTask)
        } else if hasCalendarAccess {
            async let eventsTask: Void = loadToday()
            _ = await (health, approvals, proposals, eventsTask)
        } else if hasReminderReadAccess {
            async let remindersTask: Void = loadReminders()
            _ = await (health, approvals, proposals, remindersTask)
        } else {
            _ = await (health, approvals, proposals)
        }
        startAutoRefresh()
    }

    /// Called from SignInView after Apple returns a credential.
    func signInWithApple(userIdentifier: String, identityToken: String?) async {
        isSigningIn = true
        tankConnectStatus = "Connecting to Tank…"
        defer { isSigningIn = false }

        // Save the Apple user ID locally for display / re-auth.
        TankConfiguration.saveAppleUserID(userIdentifier)

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
            lastError = tankAvailable
                ? "Tank didn't recognise this Apple ID. Make sure you've run the setup once at home."
                : "Tank is unreachable. Make sure you're on your home network and Tank is running."
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
        guard TankConfiguration.currentToken != nil else { return }
        isLoadingApprovals = true
        defer { isLoadingApprovals = false }
        do {
            approvals = try await tank.approvals()
        } catch {
            approvals = []
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
        guard TankConfiguration.currentToken != nil else { return }
        isLoadingProposals = true
        defer { isLoadingProposals = false }
        do {
            proposals = try await tank.proposals()
        } catch {
            proposals = []
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

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                if self.tankAvailable {
                    await self.loadApprovals()
                    await self.loadProposals()
                }
            }
        }
    }

    private func localResponse(for text: String) -> ConversationEntry {
        let normalized = text.lowercased()
        let response: String

        if normalized.contains("calendar") || normalized.contains("today") || normalized.contains("agenda") {
            if calendarStatus == .fullAccess || calendarStatus == .authorized {
                response = localAgendaSummary
            } else {
                response = "I can build that from your real calendar. Open Today and approve Calendar access when you’re ready."
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
            actions.append("Create a prep reminder block for “\(prepReminder.title)”.")
        }
        actions.append("Re-check afternoon priorities after your second major commitment.")
        return Array(actions.prefix(4))
    }

    private func contextLabel(_ context: BriefingContextBucket) -> String {
        context.title
    }
}

@MainActor
private final class CalendarService {
    private let store = EKEventStore()

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    func requestReminderAccess() async throws -> Bool {
        try await store.requestFullAccessToReminders()
    }

    func todayEvents() -> [DayEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let source = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        var result = source.map {
            DayEvent(
                id: $0.eventIdentifier ?? UUID().uuidString,
                title: $0.title.isEmpty ? "Untitled event" : $0.title,
                start: $0.startDate,
                end: $0.endDate,
                location: $0.location,
                calendarName: $0.calendar.title,
                context: Self.context(for: $0.calendar.title)
            )
        }
        for index in result.indices.dropLast() {
            result[index].overlapsNext = result[index].end > result[index + 1].start
        }
        return result
    }

    func todayReminders() async -> [DayReminder] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: start,
            ending: end,
            calendars: nil
        )
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let items = (reminders ?? []).map {
                    DayReminder(
                        id: $0.calendarItemIdentifier,
                        title: $0.title.isEmpty ? "Untitled reminder" : $0.title,
                        due: $0.dueDateComponents?.date,
                        calendarName: $0.calendar.title,
                        context: Self.context(for: $0.calendar.title)
                    )
                }
                .sorted { lhs, rhs in
                    (lhs.due ?? .distantFuture) < (rhs.due ?? .distantFuture)
                }
                continuation.resume(returning: items)
            }
        }
    }

    private static func context(for calendarName: String) -> BriefingContextBucket {
        let name = calendarName.lowercased()
        if name.contains("work") || name.contains("business") { return .business }
        if name.contains("family") || name.contains("shared") { return .shared }
        return .personal
    }
}

private actor TankClient {
    func isHealthy() async -> Bool {
        guard let baseURL = TankConfiguration.currentURL,
              let token = TankConfiguration.currentToken,
              !token.isEmpty else { return false }
        var request = URLRequest(url: baseURL.appending(path: "ready"))
        request.timeoutInterval = 2
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func chat(messages: [ConversationEntry]) async throws -> TankChatResponse {
        guard let baseURL = TankConfiguration.currentURL,
              let token = TankConfiguration.currentToken,
              !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        var request = URLRequest(url: baseURL.appending(path: "chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = 50
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            TankChatRequest(
                messages: messages.suffix(20).map {
                    TankChatMessage(role: $0.role.rawValue, content: $0.text)
                }
            )
        )
        return try await fetch(TankChatResponse.self, for: request)
    }

    func createBriefing(events: [DayEvent], reminders: [DayReminder]) async throws -> DailyBriefing {
        var request = try authorizedRequest(path: "briefing", method: "POST")
        let time = DateFormatter()
        time.locale = Locale(identifier: "en_US_POSIX")
        time.dateFormat = "HH:mm"
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        request.httpBody = try JSONEncoder().encode(
            TankBriefingRequest(
                date: day.string(from: Date()),
                calendar: events.map {
                    TankBriefingCalendarItem(
                        title: $0.title,
                        start: time.string(from: $0.start),
                        end: time.string(from: $0.end),
                        location: $0.location,
                        context: $0.context.rawValue
                    )
                },
                reminders: reminders.map {
                    TankBriefingReminderItem(
                        title: $0.title,
                        due: $0.due.map { time.string(from: $0) },
                        context: $0.context.rawValue
                    )
                }
            )
        )
        return try await fetch(DailyBriefing.self, for: request)
    }

    func approvals() async throws -> [PendingApproval] {
        let request = try authorizedRequest(path: "agent/approvals", method: "GET")
        return try await fetch([PendingApproval].self, for: request)
    }

    func decideApproval(id: String, decision: String) async throws -> PendingApproval {
        var request = try authorizedRequest(path: "agent/approvals/\(id)", method: "POST")
        request.httpBody = try JSONEncoder().encode(ApprovalDecisionRequest(decision: decision))
        return try await fetch(PendingApproval.self, for: request)
    }

    func proposals() async throws -> [AgentProposal] {
        let request = try authorizedRequest(path: "agent/proposals", method: "GET")
        return try await fetch([AgentProposal].self, for: request)
    }

    func decideProposal(id: String, decision: String) async throws -> AgentProposal {
        var request = try authorizedRequest(path: "agent/proposals/\(id)/decide", method: "POST")
        request.httpBody = try JSONEncoder().encode(ProposalDecisionRequest(decision: decision))
        return try await fetch(AgentProposal.self, for: request)
    }

    /// Authenticates via Apple Identity and retrieves the Tank device token.
    /// No Authorization header needed — this is the bootstrap endpoint.
    func authWithApple(userIdentifier: String, identityToken: String?) async throws -> AppleAuthResponse {
        guard let baseURL = TankConfiguration.currentURL else {
            throw URLError(.userAuthenticationRequired)
        }
        var request = URLRequest(url: baseURL.appending(path: "auth/apple"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AppleAuthRequest(userIdentifier: userIdentifier, identityToken: identityToken)
        )
        return try await fetch(AppleAuthResponse.self, for: request)
    }

    private func authorizedRequest(path: String, method: String) throws -> URLRequest {
        guard let baseURL = TankConfiguration.currentURL,
              let token = TankConfiguration.currentToken,
              !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = 50
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func fetch<T: Decodable>(
        _ type: T.Type,
        for request: URLRequest,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(T.self, from: data)
    }
}

private enum TankConfiguration {
    private static let addressKey = "nobs.tank.address"
    private static let tokenAccount = "tank-device-token"
    private static let appleUserAccount = "tank-apple-user-id"
    private static let keychainService = "com.acburgess25.NOBS"
    private static var keychain: Keychain {
        Keychain(service: keychainService)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    static var savedAddress: String {
        if let saved = UserDefaults.standard.string(forKey: addressKey) { return saved }
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8000"
        #else
        return "http://tank.local:8000"
        #endif
    }

    static var savedToken: String { currentToken ?? "" }

    static var currentURL: URL? { normalizedURL(from: savedAddress) }
    static var currentToken: String? { try? keychain.get(tokenAccount) }
    static var savedAppleUserID: String? { try? keychain.get(appleUserAccount) }

    static func normalizedURL(from value: String) -> URL? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: clean),
              ["http", "https"].contains(url.scheme?.lowercased()),
              url.host != nil else { return nil }
        return url
    }

    static func save(address: String, token: String) throws {
        UserDefaults.standard.set(address, forKey: addressKey)
        try keychain.set(token, key: tokenAccount)
    }

    static func saveAppleUserID(_ userID: String) {
        try? keychain.set(userID, key: appleUserAccount)
    }
}

private struct TankChatRequest: Codable {
    let messages: [TankChatMessage]
}

private struct TankChatMessage: Codable {
    let role: String
    let content: String
}

private struct TankChatResponse: Codable {
    let message: String
    let route: ProcessingRoute
    let privacyReceipt: PrivacyReceipt

    enum CodingKeys: String, CodingKey {
        case message
        case route
        case privacyReceipt = "privacy_receipt"
    }

    var receipt: PrivacyReceipt { privacyReceipt }
}

private struct TankBriefingRequest: Codable {
    let date: String
    let calendar: [TankBriefingCalendarItem]
    let reminders: [TankBriefingReminderItem]
}

private struct TankBriefingCalendarItem: Codable {
    let title: String
    let start: String
    let end: String?
    let location: String?
    let context: String
}

private struct TankBriefingReminderItem: Codable {
    let title: String
    let due: String?
    let context: String
}

private struct ApprovalDecisionRequest: Codable {
    let decision: String
}

private struct ProposalDecisionRequest: Codable {
    let decision: String
}

private struct AppleAuthRequest: Codable {
    let userIdentifier: String
    let identityToken: String?

    enum CodingKeys: String, CodingKey {
        case userIdentifier = "user_identifier"
        case identityToken = "identity_token"
    }
}

private struct AppleAuthResponse: Codable {
    let deviceToken: String

    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
    }
}
