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

enum AppSection: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case today = "Today"
    case memory = "Memory"
    case activity = "Activity"
    case home = "Home"
    case privacy = "Privacy"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .chat: "message"
        case .today: "sun.max"
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
    @Published var tankAddress = TankConfiguration.savedAddress
    @Published var tankToken = TankConfiguration.savedToken

    private let calendar = CalendarService()
    private let tank = TankClient()

    var activeRoute: ProcessingRoute { tankAvailable ? .tank : .local }

    func start() async {
        async let health: Void = refreshTankStatus()
        if calendarStatus == .fullAccess || calendarStatus == .authorized {
            async let events: Void = loadToday()
            _ = await (health, events)
        } else {
            await health
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
}

private enum TankConfiguration {
    private static let addressKey = "nobs.tank.address"
    private static let tokenAccount = "tank-device-token"
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
    static var currentToken: String? {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func normalizedURL(from value: String) -> URL? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: clean),
              ["http", "https"].contains(url.scheme?.lowercased()),
              url.host != nil else { return nil }
        return url
    }

    static func save(address: String, token: String) throws {
        UserDefaults.standard.set(address, forKey: addressKey)
        SecItemDelete(keychainQuery as CFDictionary)
        var query = keychainQuery
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    private static var keychainQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenAccount,
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
