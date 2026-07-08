import Foundation

actor TankClient {
    private(set) var lastConnectionError: TankAPIError?

    func checkReachability() async -> Bool {
        do {
            try await performHealthCheck(path: "health", requiresAuth: false, timeout: 3)
            lastConnectionError = nil
            return true
        } catch let error as TankAPIError {
            lastConnectionError = error
            return false
        } catch {
            let mapped = TankAPIError.map(error)
            lastConnectionError = mapped
            return false
        }
    }

    func checkHealth() async -> Bool {
        do {
            try await performHealthCheck(path: "ready", requiresAuth: true, timeout: 2)
            lastConnectionError = nil
            return true
        } catch let error as TankAPIError {
            lastConnectionError = error
            return false
        } catch {
            let mapped = TankAPIError.map(error)
            lastConnectionError = mapped
            return false
        }
    }

    func chat(messages: [ConversationEntry]) async throws -> TankChatResponse {
        try await request(
            TankChatResponse.self,
            path: "chat",
            method: "POST",
            body: TankChatRequest(
                messages: messages.suffix(20).map {
                    TankChatMessage(role: $0.role.rawValue, content: $0.text)
                }
            ),
            timeout: 50
        )
    }

    func createBriefing(
        kind: BriefingKind,
        events: [DayEvent],
        reminders: [DayReminder],
        tomorrowEvents: [DayEvent] = [],
        tomorrowReminders: [DayReminder] = []
    ) async throws -> DailyBriefing {
        let time = DateFormatter()
        time.locale = Locale(identifier: "en_US_POSIX")
        time.dateFormat = "HH:mm"
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        return try await request(
            DailyBriefing.self,
            path: "briefing",
            method: "POST",
            body: TankBriefingRequest(
                date: day.string(from: Date()),
                kind: kind.rawValue,
                calendar: mapCalendarItems(events, formatter: time),
                reminders: mapReminderItems(reminders, formatter: time),
                tomorrowCalendar: mapCalendarItems(tomorrowEvents, formatter: time),
                tomorrowReminders: mapReminderItems(tomorrowReminders, formatter: time)
            ),
            timeout: 50
        )
    }

    private func mapCalendarItems(_ events: [DayEvent], formatter: DateFormatter) -> [TankBriefingCalendarItem] {
        events.map {
            TankBriefingCalendarItem(
                title: $0.title,
                start: formatter.string(from: $0.start),
                end: formatter.string(from: $0.end),
                location: $0.location,
                context: $0.context.rawValue
            )
        }
    }

    private func mapReminderItems(_ reminders: [DayReminder], formatter: DateFormatter) -> [TankBriefingReminderItem] {
        reminders.map {
            TankBriefingReminderItem(
                title: $0.title,
                due: $0.due.map { formatter.string(from: $0) },
                context: $0.context.rawValue
            )
        }
    }

    func approvals() async throws -> [PendingApproval] {
        try await request([PendingApproval].self, path: "agent/approvals", method: "GET")
    }

    func decideApproval(id: String, decision: String) async throws -> PendingApproval {
        try await request(
            PendingApproval.self,
            path: "agent/approvals/\(id)",
            method: "POST",
            body: ApprovalDecisionRequest(decision: decision)
        )
    }

    func proposals() async throws -> [AgentProposal] {
        try await request([AgentProposal].self, path: "agent/proposals", method: "GET")
    }

    func decideProposal(id: String, decision: String) async throws -> AgentProposal {
        try await request(
            AgentProposal.self,
            path: "agent/proposals/\(id)/decide",
            method: "POST",
            body: ProposalDecisionRequest(decision: decision)
        )
    }

    func schedules() async throws -> [TankSchedule] {
        try await request([TankSchedule].self, path: "schedules", method: "GET")
    }

    func updateSchedule(id: String, status: String) async throws -> TankSchedule {
        try await request(
            TankSchedule.self,
            path: "schedules/\(id)",
            method: "PATCH",
            body: TankScheduleUpdateRequest(status: status)
        )
    }

    func memories() async throws -> [TankMemory] {
        try await request([TankMemory].self, path: "memories", method: "GET")
    }

    func updateMemory(id: String, content: String?, category: String?) async throws -> TankMemory {
        try await request(
            TankMemory.self,
            path: "memories/\(id)",
            method: "PATCH",
            body: TankMemoryUpdateRequest(content: content, category: category)
        )
    }

    func deleteMemory(id: String) async throws {
        try await requestVoid(path: "memories/\(id)", method: "DELETE")
    }

    func homeDevices(domain: String? = nil) async throws -> HomeDevicesResponse {
        var path = "home/devices"
        if let domain, !domain.isEmpty {
            let encoded = domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? domain
            path += "?domain=\(encoded)"
        }
        return try await request(HomeDevicesResponse.self, path: path, method: "GET", timeout: 20)
    }

    func researchJobs() async throws -> [ResearchJob] {
        try await request([ResearchJob].self, path: "research", method: "GET", timeout: 30)
    }

    func createResearch(topic: String, context: String) async throws -> ResearchJob {
        try await request(
            ResearchJob.self,
            path: "research",
            method: "POST",
            body: TankResearchRequest(topic: topic, context: context),
            timeout: 120
        )
    }

    func syncCalendar(events: [TankBriefingCalendarItem]) async throws {
        try await requestVoid(
            path: "sync/calendar",
            method: "POST",
            body: TankSyncCalendarRequest(events: events)
        )
    }

    func syncReminders(reminders: [TankBriefingReminderItem]) async throws {
        try await requestVoid(
            path: "sync/reminders",
            method: "POST",
            body: TankSyncRemindersRequest(reminders: reminders)
        )
    }

    func authWithApple(userIdentifier: String, identityToken: String?) async throws -> AppleAuthResponse {
        guard let baseURL = TankConfiguration.currentURL else {
            throw TankAPIError.notConfigured
        }
        var request = URLRequest(url: baseURL.appending(path: "auth/apple"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AppleAuthRequest(userIdentifier: userIdentifier, identityToken: identityToken)
        )
        return try await decodeResponse(AppleAuthResponse.self, prepared: request, requiresAuth: false)
    }

    private func performHealthCheck(path: String, requiresAuth: Bool, timeout: TimeInterval) async throws {
        guard let baseURL = TankConfiguration.currentURL else {
            throw TankAPIError.notConfigured
        }
        if requiresAuth {
            guard let token = TankConfiguration.currentToken, !token.isEmpty else {
                throw TankAPIError.notConfigured
            }
        }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.timeoutInterval = timeout
        if requiresAuth, let token = TankConfiguration.currentToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await performData(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw TankAPIError.httpStatus(response.statusCode, bodySnippet: "")
        }
    }

    private func request<T: Decodable>(
        _ type: T.Type,
        path: String,
        method: String,
        body: (any Encodable)? = nil,
        timeout: TimeInterval = 50,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let request = try authorizedRequest(path: path, method: method, body: body, timeout: timeout)
        return try await decodeResponse(T.self, prepared: request, requiresAuth: true, decoder: decoder)
    }

    private func decodeResponse<T: Decodable>(
        _ type: T.Type,
        prepared request: URLRequest,
        requiresAuth: Bool,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let (data, response) = try await performData(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw TankAPIError.httpStatus(response.statusCode, bodySnippet: TankAPIError.bodySnippet(from: data))
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw TankAPIError.decoding(error)
        }
    }

    private func requestVoid(
        path: String,
        method: String,
        body: (any Encodable)? = nil,
        timeout: TimeInterval = 50
    ) async throws {
        let request = try authorizedRequest(path: path, method: method, body: body, timeout: timeout)
        let (data, response) = try await performData(for: request)
        guard (200...299).contains(response.statusCode) else {
            throw TankAPIError.httpStatus(response.statusCode, bodySnippet: TankAPIError.bodySnippet(from: data))
        }
    }

    private func authorizedRequest(
        path: String,
        method: String,
        body: (any Encodable)? = nil,
        timeout: TimeInterval = 50
    ) throws -> URLRequest {
        guard let baseURL = TankConfiguration.currentURL,
              let token = TankConfiguration.currentToken,
              !token.isEmpty else {
            throw TankAPIError.notConfigured
        }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    private func performData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw TankAPIError.network(URLError(.badServerResponse))
            }
            return (data, http)
        } catch let error as TankAPIError {
            throw error
        } catch let error as URLError {
            throw TankAPIError.network(error)
        } catch {
            throw TankAPIError.map(error)
        }
    }
}

struct TankChatRequest: Codable {
    let messages: [TankChatMessage]
}

struct TankChatMessage: Codable {
    let role: String
    let content: String
}

struct TankChatResponse: Codable {
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

struct TankBriefingRequest: Codable {
    let date: String
    let kind: String
    let calendar: [TankBriefingCalendarItem]
    let reminders: [TankBriefingReminderItem]
    let tomorrowCalendar: [TankBriefingCalendarItem]
    let tomorrowReminders: [TankBriefingReminderItem]

    enum CodingKeys: String, CodingKey {
        case date, kind, calendar, reminders
        case tomorrowCalendar = "tomorrow_calendar"
        case tomorrowReminders = "tomorrow_reminders"
    }
}

struct TankBriefingCalendarItem: Codable {
    let title: String
    let start: String
    let end: String?
    let location: String?
    let context: String
}

struct TankBriefingReminderItem: Codable {
    let title: String
    let due: String?
    let context: String
}

struct ApprovalDecisionRequest: Codable {
    let decision: String
}

struct ProposalDecisionRequest: Codable {
    let decision: String
}

struct TankScheduleUpdateRequest: Codable {
    let status: String
}

struct TankMemoryUpdateRequest: Codable {
    let content: String?
    let category: String?
}

struct TankResearchRequest: Codable {
    let topic: String
    let context: String
}

struct AppleAuthRequest: Codable {
    let userIdentifier: String
    let identityToken: String?

    enum CodingKeys: String, CodingKey {
        case userIdentifier = "user_identifier"
        case identityToken = "identity_token"
    }
}

struct AppleAuthResponse: Codable {
    let deviceToken: String

    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
    }
}

struct TankSyncCalendarRequest: Codable {
    let events: [TankBriefingCalendarItem]
}

struct TankSyncRemindersRequest: Codable {
    let reminders: [TankBriefingReminderItem]
}
