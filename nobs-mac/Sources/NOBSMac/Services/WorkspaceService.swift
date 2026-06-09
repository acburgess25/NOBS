import AppKit
import Foundation

struct WorkspaceService {
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private let publicBaseURL = URL(string: "https://nobsdash.com")!
    private let onlineModel = "qwen2.5-coder:14b"

    var aiRoot:      URL { home.appending(path: "nobs-tank-ai") }
    var nobsAppRoot: URL { home.appending(path: "nobs/nobs-app") }
    var vaultRoot:   URL { home.appending(path: "nobs/vault") }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func runDistillation() async -> String {
        await runShell(home.appending(path: ".local/bin/distill-ai-memory").path())
    }

    func askLocalModel(_ prompt: String) async -> String {
        await runShell(home.appending(path: ".local/bin/ask").path(), arguments: [prompt])
    }

    func approveMorningDocument() async -> String {
        await runShell(
            home.appending(path: "nobs/nobs-mac/script/generate_morning_document.sh").path(),
            arguments: ["--approve", "--force"]
        )
    }

    func isOnlineRouteAvailable() async -> Bool {
        var request = URLRequest(url: publicBaseURL.appending(path: "api/v1/ping"))
        request.timeoutInterval = 2

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func askOnlineModel(_ prompt: String) async throws -> String {
        let url = publicBaseURL.appending(path: "ollama/v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            OnlineChatRequest(
                model: onlineModel,
                messages: [
                    OnlineChatMessage(role: "system", content: "You are Tank AI, a concise personal AI for Alex and his boyfriend. Keep private memory separate unless sharing is explicitly approved."),
                    OnlineChatMessage(role: "user", content: prompt)
                ],
                temperature: 0.2,
                maxTokens: 800
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OnlineChatResponse.self, from: data)
        return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func runShell(_ command: String, arguments: [String] = []) async -> String {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(filePath: command)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            } catch {
                return error.localizedDescription
            }
        }.value
    }
}

private struct OnlineChatRequest: Encodable {
    let model: String
    let messages: [OnlineChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct OnlineChatMessage: Codable {
    let role: String
    let content: String
}

private struct OnlineChatResponse: Decodable {
    let choices: [OnlineChatChoice]
}

private struct OnlineChatChoice: Decodable {
    let message: OnlineChatMessage
}
