import Combine
import EventKit
import Foundation
import Security

enum ProcessingRoute: String, Codable {
    case local = "Local"
    case tank = "Tank"
    case cloud = "NOBScloud"
}

struct PrivacyReceipt: Codable, Hashable {
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

struct ConversationEntry: Identifiable, Codable {
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

struct DayEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let calendarName: String

    var overlapsNext: Bool = false
}

struct DailyBriefing: Codable {
    let date: String
    let personal: String
    let business: String
    let shared: String
    let generatedAt: String
    let route: ProcessingRoute
    let privacyReceipt: PrivacyReceipt

    enum CodingKeys: String, CodingKey {
        case date, personal, business, shared, route
        case generatedAt = "generated_at"
        case privacyReceipt = "privacy_receipt"
    }
}

struct PendingApproval: Identifiable, Codable {
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

struct AgentProposal: Identifiable, Codable {
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

/// Type-erased Codable wrapper for heterogeneous JSON values (approval arguments).
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode([String: AnyCodable].self) { value = v }
        else if let v = try? container.decode([AnyCodable].self) { value = v }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [String: AnyCodable]: try container.encode(v)
        case let v as [AnyCodable]: try container.encode(v)
        default: try container.encodeNil()
        }
    }

    var displayString: String {
        switch value {
        case let v as String: return v
        case let v as Bool: return v ? "true" : "false"
        case let v as Int: return "\(v)"
        case let v as Double: return "\(v)"
        default: return "\(value)"
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
    @Published var calendarStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var isLoadingCalendar = false
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

    var activeRoute: ProcessingRoute { tankAvailable ? .tank : .local }

    /// Total count of items needing a decision (shown as badge).
    var pendingDecisionCount: Int {
        approvals.filter { $0.status == "pending" }.count +
        proposals.filter { $0.status == "pending" }.count
    }

    func start() async {
        async let health: Void = refreshTankStatus()
        async let approvals: Void = loadApprovals()
        async let proposals: Void = loadProposals()
        if calendarStatus == .fullAccess || calendarStatus == .authorized {
            async let events: Void = loadToday()
            _ = await (health, approvals, proposals, events)
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
            activity.insert("Signed in with Apple and connected to Tank", at: 0)
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
                activity.insert("Calendar access approved", at: 0)
                await loadToday()
            } else {
                lastError = "Calendar access was not granted. NOBS still works as private chat."
            }
        } catch {
            lastError = "Calendar access could not be requested: \(error.localizedDescription)"
        }
    }

    func loadToday() async {
        isLoadingCalendar = true
        defer { isLoadingCalendar = false }
        events = calendar.todayEvents()
        activity.insert("Loaded \(events.count) calendar events locally", at: 0)
    }

    func refreshTankStatus() async {
        tankAvailable = await tank.isHealthy()
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
            activity.insert(
                tankAvailable ? "Tank connection verified" : "Tank connection saved; server unavailable",
                at: 0
            )
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
                activity.insert("Tank answered a chat request", at: 0)
                return
            } catch {
                tankAvailable = false
                lastError = "Tank went offline. This request stayed on your iPhone."
            }
        }

        entries.append(localResponse(for: clean))
    }

    func generateBriefing() async {
        guard tankAvailable, !isGeneratingBriefing else {
            lastError = "Tank is offline, so your calendar stayed on this iPhone. Reconnect Tank to create the briefing."
            return
        }
        isGeneratingBriefing = true
        defer { isGeneratingBriefing = false }
        do {
            briefing = try await tank.createBriefing(events: events)
            activity.insert(
                "Tank created a briefing from \(events.count) visible calendar events",
                at: 0
            )
        } catch {
            tankAvailable = false
            lastError = "Tank could not create the briefing. Your calendar remains available locally."
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
            activity.insert(
                "\(decision == "approve" ? "Approved" : "Denied") \(approval.toolName)",
                at: 0
            )
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
            activity.insert(
                "\(decision == "approve" ? "Approved" : "Dismissed") idea: \(proposal.title)",
                at: 0
            )
            await loadProposals()
        } catch {
            lastError = "Tank could not update that proposal. It may already have been decided."
        }
    }

    private func startAutoRefresh() {
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(30))
                guard let self else { return }
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

    private var localAgendaSummary: String {
        guard !events.isEmpty else { return "Your calendar is clear for the rest of today." }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let first = events[0]
        let conflicts = events.filter(\.overlapsNext).count
        let conflictText = conflicts == 0 ? "I found no overlaps." : "I found \(conflicts) schedule conflict\(conflicts == 1 ? "" : "s")."
        return "You have \(events.count) event\(events.count == 1 ? "" : "s") today. First is \(first.title) at \(formatter.string(from: first.start)). \(conflictText)"
    }
}

@MainActor
private final class CalendarService {
    private let store = EKEventStore()

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
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
                calendarName: $0.calendar.title
            )
        }
        for index in result.indices.dropLast() {
            result[index].overlapsNext = result[index].end > result[index + 1].start
        }
        return result
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
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(TankChatResponse.self, from: data)
    }

    func createBriefing(events: [DayEvent]) async throws -> DailyBriefing {
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
                        context: Self.context(for: $0.calendarName)
                    )
                },
                reminders: []
            )
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(DailyBriefing.self, from: data)
    }

    func approvals() async throws -> [PendingApproval] {
        let request = try authorizedRequest(path: "agent/approvals", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([PendingApproval].self, from: data)
    }

    func decideApproval(id: String, decision: String) async throws -> PendingApproval {
        var request = try authorizedRequest(path: "agent/approvals/\(id)", method: "POST")
        request.httpBody = try JSONEncoder().encode(ApprovalDecisionRequest(decision: decision))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PendingApproval.self, from: data)
    }

    func proposals() async throws -> [AgentProposal] {
        let request = try authorizedRequest(path: "agent/proposals", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        return try decoder.decode([AgentProposal].self, from: data)
    }

    func decideProposal(id: String, decision: String) async throws -> AgentProposal {
        var request = try authorizedRequest(path: "agent/proposals/\(id)/decide", method: "POST")
        request.httpBody = try JSONEncoder().encode(ProposalDecisionRequest(decision: decision))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AgentProposal.self, from: data)
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
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AppleAuthResponse.self, from: data)
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

    private static func context(for calendarName: String) -> String {
        let name = calendarName.lowercased()
        if name.contains("work") || name.contains("business") { return "business" }
        if name.contains("family") || name.contains("shared") { return "shared" }
        return "personal"
    }
}

private enum TankConfiguration {
    private static let addressKey = "nobs.tank.address"
    private static let tokenAccount = "tank-device-token"
    private static let appleUserAccount = "tank-apple-user-id"
    private static let keychainService = "com.acburgess25.NOBS"

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
    static var currentToken: String? { keychainRead(account: tokenAccount) }
    static var savedAppleUserID: String? { keychainRead(account: appleUserAccount) }

    static func normalizedURL(from value: String) -> URL? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: clean),
              ["http", "https"].contains(url.scheme?.lowercased()),
              url.host != nil else { return nil }
        return url
    }

    static func save(address: String, token: String) throws {
        UserDefaults.standard.set(address, forKey: addressKey)
        try keychainWrite(account: tokenAccount, value: token)
    }

    static func saveAppleUserID(_ userID: String) {
        try? keychainWrite(account: appleUserAccount, value: userID)
    }

    private static func keychainRead(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainWrite(account: String, value: String) throws {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
    }

    private enum KeychainError: Error {
        case saveFailed(OSStatus)
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
    let context: String
}

private struct TankBriefingReminderItem: Codable {
    let title: String
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
