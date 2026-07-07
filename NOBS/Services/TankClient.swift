import Foundation

actor TankClient {
    func isReachable() async -> Bool {
        guard let baseURL = TankConfiguration.currentURL else { return false }
        var request = URLRequest(url: baseURL.appending(path: "health"))
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

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

    func schedules() async throws -> [TankSchedule] {
        let request = try authorizedRequest(path: "schedules", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([TankSchedule].self, from: data)
    }

    func updateSchedule(id: String, status: String) async throws -> TankSchedule {
        var request = try authorizedRequest(path: "schedules/\(id)", method: "PATCH")
        request.httpBody = try JSONEncoder().encode(TankScheduleUpdateRequest(status: status))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(TankSchedule.self, from: data)
    }

    func syncCalendar(events: [TankBriefingCalendarItem]) async throws {
        var request = try authorizedRequest(path: "sync/calendar", method: "POST")
        request.httpBody = try JSONEncoder().encode(TankSyncCalendarRequest(events: events))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    func syncReminders(reminders: [TankBriefingReminderItem]) async throws {
        var request = try authorizedRequest(path: "sync/reminders", method: "POST")
        request.httpBody = try JSONEncoder().encode(TankSyncRemindersRequest(reminders: reminders))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

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
    let calendar: [TankBriefingCalendarItem]
    let reminders: [TankBriefingReminderItem]
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
