import Foundation

struct TankChatReply: Decodable {
    struct Receipt: Decodable {
        let used: [String]
        let processed: String
        let shared: [String]
        let changed: [String]
    }

    let message: String
    let route: String
    let privacyReceipt: Receipt

    enum CodingKeys: String, CodingKey {
        case message
        case route
        case privacyReceipt = "privacy_receipt"
    }
}

/// Thin client for the local NOBS Tank API and the Ollama runtime.
struct TankClient: Sendable {
    private var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        return URLSession(configuration: configuration)
    }

    func isHealthy(baseURL: URL) async -> Bool {
        await statusCode(for: URLRequest(url: baseURL.appending(path: "health"))) == 200
    }

    func isReady(baseURL: URL, token: String) async -> Bool {
        var request = URLRequest(url: baseURL.appending(path: "ready"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return await statusCode(for: request) == 200
    }

    func isOllamaRunning() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:11434/api/version") else { return false }
        return await statusCode(for: URLRequest(url: url)) == 200
    }

    func chat(baseURL: URL, token: String, message: String) async throws -> TankChatReply {
        var request = URLRequest(url: baseURL.appending(path: "chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ["messages": [["role": "user", "content": message]]]
        )
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(TankChatReply.self, from: data)
    }

    private func statusCode(for request: URLRequest) async -> Int? {
        guard let (_, response) = try? await session.data(for: request) else { return nil }
        return (response as? HTTPURLResponse)?.statusCode
    }
}
