/// NOBSCore — Apple Intelligence (on-device) Model Client
///
/// Wraps Apple's `FoundationModels` framework so NOBS can run inference
/// fully on-device on iOS 26 / macOS 15+. Falls back gracefully on older OSes
/// (the type still compiles but `isAvailable` returns false and calls throw).
///
/// Why this exists alongside `ModelClient`:
///  • `ModelClient`  → HTTP to local Ollama / LiteLLM / OpenAI-compatible servers
///                     (used when the device has Tailscale reach to tank, or for
///                     models bigger than what the iPhone can run.)
///  • `FoundationModelsClient` → Apple's bundled on-device LLM, runs anywhere,
///                     no network, no token cost, integrates with Apple Intelligence.
///
/// Typical wiring:
/// ```swift
/// let llm: any LLMBackend = FoundationModelsClient.isAvailable
///     ? FoundationModelsClient()
///     : ModelClient(config: .tank)         // Tailscale fallback
/// let reply = try await llm.chat(messages: history)
/// ```

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - StructuredIntentResult

/// Type-safe intent output from structured generation. Falls back to `nil` on
/// non-Apple backends or older OS versions — callers should handle both paths.
public struct StructuredIntentResult: Sendable {
    public let intent: String
    public let reply: String
    public let params: [String: String]

    public init(intent: String, reply: String, params: [String: String] = [:]) {
        self.intent = intent
        self.reply = reply
        self.params = params
    }
}

// MARK: - LLMBackend protocol

/// Common surface area for any chat-capable backend. `ModelClient` already
/// matches this shape; new backends (Foundation Models, MLX, llama.cpp, etc.)
/// should conform so the assistant can swap them out without changes.
public protocol LLMBackend: Sendable {
    /// Send a multi-turn conversation and receive the assistant reply text.
    func chat(messages: [ChatMessage]) async throws -> String

    /// Attempt structured generation — returns a parsed intent result, or `nil`
    /// when the backend doesn't support it (e.g. HTTP ModelClient).
    func generateStructured(messages: [ChatMessage]) async throws -> StructuredIntentResult?

    /// Stream response tokens as they generate. Each yielded `String` is the delta
    /// (new characters only). Default wraps `chat()` emitting the full response at once.
    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}

public extension LLMBackend {
    func generateStructured(messages: [ChatMessage]) async throws -> StructuredIntentResult? { nil }

    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await self.chat(messages: messages)
                    continuation.yield(response)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// Make the existing HTTP client conform without altering its file.
extension ModelClient: LLMBackend {}

// MARK: - NOBSIntentOutput (@Generable — Foundation Models structured output)

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct NOBSIntentOutput {
    @Guide(description: "The intent name: makeCall, screenCall, endCall, sendMessage, readMessages, controlDevice, runScene, queryDevice, createReminder, listReminders, completeReminder, browseWeb, storeMemory, recallMemory, or chat")
    var intent: String

    @Guide(description: "Friendly, conversational reply text to show the user")
    var reply: String

    @Guide(description: "Phone number for makeCall, screenCall, or sendMessage intents")
    var phoneNumber: String?

    @Guide(description: "Human-readable contact name for makeCall")
    var contactName: String?

    @Guide(description: "Recipient identifier (phone or name) for sendMessage or readMessages")
    var to: String?

    @Guide(description: "Body text of the message for sendMessage")
    var body: String?

    @Guide(description: "Smart home device name for controlDevice or queryDevice")
    var deviceName: String?

    @Guide(description: "Home control action: turnOn, turnOff, setBrightness, setTemperature, lock, or unlock")
    var action: String?

    @Guide(description: "Scene name for runScene")
    var sceneName: String?

    @Guide(description: "Reminder or task title for createReminder")
    var title: String?

    @Guide(description: "ISO 8601 due date string for createReminder, e.g. 2026-06-15T14:00:00Z")
    var dueDate: String?

    @Guide(description: "Optional extra notes for createReminder")
    var notes: String?

    @Guide(description: "Reminder ID string for completeReminder")
    var id: String?

    @Guide(description: "Text content to store for storeMemory")
    var content: String?

    @Guide(description: "Search query for recallMemory or browseWeb")
    var query: String?

    @Guide(description: "Data context for the action: personal or work")
    var context: String?
}
#endif

// MARK: - FoundationModelsClient

public actor FoundationModelsClient: LLMBackend {

    /// True when the device actually has an Apple Intelligence on-device model available.
    /// Apple gates this on hardware (e.g. A17 Pro+ for iPhone) + the framework being present.
    public static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        return false
        #else
        return false
        #endif
    }

    /// Optional system instructions reused across calls. Set this to the NOBS
    /// persona / output-format prompt; the per-call `messages` then carry the
    /// turn-by-turn conversation.
    public let defaultInstructions: String?

    /// Generation knobs. Mapped onto `GenerationOptions` per call.
    public var temperature: Double
    public var maxTokens: Int

    public init(
        defaultInstructions: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 2048
    ) {
        self.defaultInstructions = defaultInstructions
        self.temperature = min(1.0, max(0.0, temperature))
        self.maxTokens = max(1, maxTokens)
    }

    // MARK: LLMBackend — text chat

    public func chat(messages: [ChatMessage]) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else {
            throw ModelClientError.invalidEndpoint("FoundationModels requires iOS 26 / macOS 15+")
        }
        guard Self.isAvailable else {
            throw ModelClientError.invalidEndpoint("Apple Intelligence model not available on this device")
        }

        let systemBlocks = messages
            .filter { $0.role == .system }
            .map(\.content)
        let turnBlocks = messages
            .filter { $0.role != .system }
            .map { "\($0.role.rawValue.uppercased()): \($0.content)" }
            .joined(separator: "\n")

        let instructions = ([defaultInstructions].compactMap { $0 } + systemBlocks)
            .joined(separator: "\n\n")

        let session = LanguageModelSession(instructions: instructions.isEmpty ? nil : instructions)
        let options = GenerationOptions(
            temperature: temperature,
            maximumResponseTokens: maxTokens
        )

        do {
            let response = try await session.respond(to: turnBlocks, options: options)
            let text = response.content
            guard !text.isEmpty else { throw ModelClientError.emptyResponse }
            return text
        } catch let err as ModelClientError {
            throw err
        } catch {
            throw ModelClientError.networkError(error)
        }
        #else
        throw ModelClientError.invalidEndpoint("FoundationModels framework not available in this SDK")
        #endif
    }

    // MARK: LLMBackend — structured generation

    public func generateStructured(messages: [ChatMessage]) async throws -> StructuredIntentResult? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return nil }
        guard Self.isAvailable else { return nil }

        let systemBlocks = messages
            .filter { $0.role == .system }
            .map(\.content)
        let turnBlocks = messages
            .filter { $0.role != .system }
            .map { "\($0.role.rawValue.uppercased()): \($0.content)" }
            .joined(separator: "\n")

        let instructions = ([defaultInstructions].compactMap { $0 } + systemBlocks)
            .joined(separator: "\n\n")

        let session = LanguageModelSession(instructions: instructions.isEmpty ? nil : instructions)

        do {
            let response = try await session.respond(to: turnBlocks, generating: NOBSIntentOutput.self)
            return mapIntentOutput(response.content)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: LLMBackend — streaming

    public nonisolated func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let defaultInstructions = self.defaultInstructions

        return AsyncThrowingStream { continuation in
            Task {
                #if canImport(FoundationModels)
                if #available(iOS 26.0, macOS 26.0, *) {
                    guard FoundationModelsClient.isAvailable else {
                        continuation.finish(throwing: ModelClientError.invalidEndpoint("Apple Intelligence model not available on this device"))
                        return
                    }

                    let temperature = await self.temperature
                    let maxTokens = await self.maxTokens

                    let systemBlocks = messages.filter { $0.role == .system }.map(\.content)
                    let turnBlocks = messages.filter { $0.role != .system }
                        .map { "\($0.role.rawValue.uppercased()): \($0.content)" }
                        .joined(separator: "\n")
                    let instructions = ([defaultInstructions].compactMap { $0 } + systemBlocks)
                        .joined(separator: "\n\n")

                    let session = LanguageModelSession(instructions: instructions.isEmpty ? nil : instructions)
                    let options = GenerationOptions(temperature: temperature, maximumResponseTokens: maxTokens)

                    do {
                        let responseStream = session.streamResponse(to: turnBlocks, options: options)
                        var accumulated = ""
                        for try await snapshot in responseStream {
                            let full = snapshot.content
                            if full.count > accumulated.count {
                                let delta = String(full.dropFirst(accumulated.count))
                                continuation.yield(delta)
                                accumulated = full
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                    return
                }
                #endif
                continuation.finish(throwing: ModelClientError.invalidEndpoint("FoundationModels requires iOS 26 / macOS 15+"))
            }
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func mapIntentOutput(_ output: NOBSIntentOutput) -> StructuredIntentResult {
        var params: [String: String] = [:]
        if let v = output.phoneNumber { params["phoneNumber"] = v }
        if let v = output.contactName { params["contactName"] = v }
        if let v = output.to          { params["to"] = v }
        if let v = output.body        { params["body"] = v }
        if let v = output.deviceName  { params["deviceName"] = v }
        if let v = output.action      { params["action"] = v }
        if let v = output.sceneName   { params["sceneName"] = v }
        if let v = output.title       { params["title"] = v }
        if let v = output.dueDate     { params["dueDate"] = v }
        if let v = output.notes       { params["notes"] = v }
        if let v = output.id          { params["id"] = v }
        if let v = output.content     { params["content"] = v }
        if let v = output.query       { params["query"] = v }
        if let v = output.context     { params["context"] = v }
        return StructuredIntentResult(intent: output.intent, reply: output.reply, params: params)
    }
    #endif
}

// MARK: - Convenience: pick the right backend for this device

public enum BackendPreference: Sendable {
    /// Always Apple on-device; throws if unavailable.
    case appleOnly
    /// Always the configured HTTP endpoint (Ollama / LiteLLM / etc.).
    case httpOnly
    /// Use Apple on-device when available, otherwise HTTP. (Recommended default.)
    case preferApple
}

public enum LLMBackendFactory {
    /// Returns the best available backend given the user's preference and the
    /// current device capabilities.
    public static func make(
        preference: BackendPreference = .preferApple,
        httpConfig: ModelConfiguration
    ) -> any LLMBackend {
        switch preference {
        case .appleOnly:
            return FoundationModelsClient()
        case .httpOnly:
            return ModelClient(config: httpConfig)
        case .preferApple:
            return FoundationModelsClient.isAvailable
                ? FoundationModelsClient()
                : ModelClient(config: httpConfig)
        }
    }
}

// MARK: - Convenience endpoint presets

public extension ModelConfiguration {
    /// Tank (RTX 3060, qwen2.5-coder:14b) via Tailscale.
    /// Used when the iPhone is on Tailscale and wants the heavy model.
    static var tank: ModelConfiguration {
        ModelConfiguration(
            localEndpoint: URL(string: "http://100.96.97.50:4000")!,
            modelName: "local-coder-14b",
            maxTokens: 2048,
            temperature: 0.7,
            timeoutSeconds: 60
        )
    }
}
