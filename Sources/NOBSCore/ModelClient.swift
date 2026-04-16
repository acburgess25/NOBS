/// NOBSCore — Local AI Model Client
///
/// Provides the networking layer that communicates with a locally hosted
/// LLM server (Ollama, LM Studio, or any OpenAI-compatible endpoint).
/// All data stays on the local network — nothing is routed to external clouds.

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Configuration

/// Shared configuration for the local model endpoint and behaviour.
public struct ModelConfiguration: Sendable {
    /// Base URL of the locally running LLM server.
    /// Example: `http://192.168.1.10:11434` (Ollama default)
    public var localEndpoint: URL

    /// Name of the model to use for inference.
    public var modelName: String

    /// Maximum tokens to generate per response.
    public var maxTokens: Int

    /// Temperature (0 = deterministic, 1 = creative).
    public var temperature: Double

    /// Connection / read timeout in seconds.
    public var timeoutSeconds: Double

    public init(
        localEndpoint: URL,
        modelName: String = "llama3",
        maxTokens: Int = 2048,
        temperature: Double = 0.7,
        timeoutSeconds: Double = 30
    ) {
        self.localEndpoint = localEndpoint
        self.modelName = modelName
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.timeoutSeconds = timeoutSeconds
    }

    /// Convenience default pointing to localhost (useful for development).
    public static var localhost: ModelConfiguration {
        ModelConfiguration(localEndpoint: URL(string: "http://127.0.0.1:11434")!)
    }
}

// MARK: - Message types

/// A single turn in a conversation with the local model.
public struct ChatMessage: Codable, Sendable {
    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

/// The raw response returned by the LLM server.
public struct ModelResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let model: String

    public struct Choice: Codable, Sendable {
        public struct Message: Codable, Sendable {
            public let role: String
            public let content: String
        }
        public let message: Message
        public let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    public let choices: [Choice]

    /// Convenience accessor for the primary response text.
    public var text: String {
        choices.first?.message.content ?? ""
    }
}

// MARK: - Errors

public enum ModelClientError: Error, LocalizedError, Sendable {
    case invalidEndpoint(String)
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError(Error)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let url):  return "Invalid model endpoint URL: \(url)"
        case .networkError(let e):       return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let code): return "Server returned HTTP \(code)"
        case .decodingError(let e):      return "Failed to decode model response: \(e.localizedDescription)"
        case .emptyResponse:             return "Model returned an empty response"
        }
    }
}

// MARK: - ModelClient

/// Async client for communicating with a locally hosted OpenAI-compatible LLM.
public actor ModelClient {
    private let config: ModelConfiguration
    private let session: URLSession

    public init(config: ModelConfiguration) {
        self.config = config
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeoutSeconds
        sessionConfig.timeoutIntervalForResource = config.timeoutSeconds * 2
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: Chat completion

    /// Send a multi-turn conversation and receive the assistant reply.
    public func chat(messages: [ChatMessage]) async throws -> String {
        let url = config.localEndpoint
            .appendingPathComponent("v1")
            .appendingPathComponent("chat")
            .appendingPathComponent("completions")

        let body: [String: Any] = [
            "model": config.modelName,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "max_tokens": config.maxTokens,
            "temperature": config.temperature,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, urlResponse): (Data, URLResponse)
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            throw ModelClientError.networkError(error)
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            throw ModelClientError.invalidResponse(0)
        }
        guard (200...299).contains(http.statusCode) else {
            throw ModelClientError.invalidResponse(http.statusCode)
        }

        let modelResponse: ModelResponse
        do {
            modelResponse = try JSONDecoder().decode(ModelResponse.self, from: data)
        } catch {
            throw ModelClientError.decodingError(error)
        }

        let text = modelResponse.text
        guard !text.isEmpty else { throw ModelClientError.emptyResponse }
        return text
    }

    /// Convenience: send a single user message with an optional system prompt.
    public func ask(_ question: String, systemPrompt: String? = nil) async throws -> String {
        var messages: [ChatMessage] = []
        if let system = systemPrompt {
            messages.append(ChatMessage(role: .system, content: system))
        }
        messages.append(ChatMessage(role: .user, content: question))
        return try await chat(messages: messages)
    }
}

// MARK: - PromptBuilder

/// Constructs system prompts that give the model context about the user and
/// which module is making the request.
public struct PromptBuilder {
    public enum Context: String, Sendable {
        case general    = "general"
        case calls      = "phone_calls"
        case messages   = "imessage"
        case homeKit    = "smart_home"
        case reminders  = "reminders"
        case webBrowse  = "web_browsing"
    }

    public static func systemPrompt(
        for context: Context,
        userName: String = "the user",
        additionalContext: String? = nil
    ) -> String {
        var prompt = """
        You are NOBS, a privacy-first personal assistant for \(userName). \
        You run entirely on the user's local network — all personal information \
        stays on-device and is never sent to external servers. \
        You are helpful, concise, and act like a trusted friend who knows how to get things done. \
        Current context: \(context.rawValue).
        """
        if let extra = additionalContext {
            prompt += "\n\nAdditional context:\n\(extra)"
        }
        return prompt
    }
}

// MARK: - IntentParser

/// Parses structured intent values out of raw model text.
/// The model is instructed to respond with a JSON envelope; this parser
/// extracts typed `AssistantIntent` values from that envelope.
public struct IntentParser {
    public enum ParseError: Error, Sendable {
        case noJSONFound
        case unknownIntent(String)
        case missingParameter(String)
    }

    /// Attempt to extract a JSON object from arbitrary model output text.
    public static func extractJSON(from text: String) throws -> [String: Any] {
        guard
            let start = text.range(of: "{"),
            let end = text.range(of: "}", options: .backwards),
            start.lowerBound <= end.lowerBound
        else { throw ParseError.noJSONFound }

        // Use a half-open range: from `{` up to (but not including) the index
        // after `}`. This avoids a fatal out-of-bounds when `}` is the last character.
        let jsonSubstring = text[start.lowerBound..<end.upperBound]
        guard
            let data = String(jsonSubstring).data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ParseError.noJSONFound }

        return obj
    }
}
