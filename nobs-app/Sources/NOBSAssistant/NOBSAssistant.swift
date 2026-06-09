/// NOBSAssistant — Central Coordinator
///
/// Receives natural-language input from the user (text or transcribed voice),
/// sends it to the local AI model via `NOBSCore.ModelClient`, parses the
/// resulting intent, and dispatches it to the appropriate module handler.

import Foundation
import NOBSCore
import NOBSDatabase

// MARK: - AssistantResponse

/// The outcome of processing a user request.
public struct AssistantResponse: Sendable {
    /// Human-readable text the assistant speaks / displays to the user.
    public let text: String

    /// The structured intent that was parsed (if any).
    public let intent: AssistantIntent?

    /// Whether the action requested by the intent was successfully executed.
    public let actionSucceeded: Bool

    public init(text: String, intent: AssistantIntent? = nil, actionSucceeded: Bool = true) {
        self.text = text
        self.intent = intent
        self.actionSucceeded = actionSucceeded
    }
}

// MARK: - IntentRouter


/// The central coordinator for the NOBS assistant.
///
/// Usage:
/// ```swift
/// let assistant = NOBSAssistant(config: .localhost)
/// let response = await assistant.process("Call Mom")
/// print(response.text)
/// ```
public actor NOBSAssistant {
    // MARK: - History bounds (defaults for conversation window)
    public static let maxHistoryMessagesDefault: Int = 40
    public static let minHistoryMessages: Int = 4

    private let backend: any LLMBackend
    private let intentRouter: IntentRouter
    private var conversationHistory: [ChatMessage] = []
    private var userName: String
    private let dataContext: DataContext

    /// Maximum number of non-system messages kept in the conversation window.
    ///
    /// When the history grows beyond this limit the oldest user/assistant pairs
    /// are dropped while the system prompt is always preserved.  This prevents
    /// unbounded memory growth and keeps requests within the model's token limit.
    public let maxHistoryMessages: Int

    /// Primary initializer — pass any `LLMBackend` (FoundationModelsClient or ModelClient).
    public init(
        backend: any LLMBackend,
        handlers: [IntentHandler] = [],
        userName: String = "User",
        dataContext: DataContext = .personal,
        maxHistoryMessages: Int = NOBSAssistant.maxHistoryMessagesDefault
    ) {
        self.backend = backend
        self.intentRouter = IntentRouter(handlers: handlers)
        self.userName = userName
        self.dataContext = dataContext
        self.maxHistoryMessages = max(NOBSAssistant.minHistoryMessages, maxHistoryMessages)
    }

    /// Convenience initializer for HTTP-only backends (backwards compatible).
    public init(
        config: ModelConfiguration,
        handlers: [IntentHandler] = [],
        userName: String = "User",
        dataContext: DataContext = .personal,
        maxHistoryMessages: Int = NOBSAssistant.maxHistoryMessagesDefault
    ) {
        self.init(
            backend: ModelClient(config: config),
            handlers: handlers,
            userName: userName,
            dataContext: dataContext,
            maxHistoryMessages: maxHistoryMessages
        )
    }

    // MARK: - Public API

    /// Process a natural-language user message and return the assistant response.
    public func process(_ userMessage: String) async -> AssistantResponse {
        guard !userMessage.trimmingCharacters(in: .whitespaces).isEmpty else {
            return AssistantResponse(text: "Please enter a valid message.", actionSucceeded: false)
        }

        let sanitizedMessage = sanitizeInput(userMessage)
        let systemPrompt = PromptBuilder.systemPrompt(
            for: .general,
            userName: userName,
            additionalContext: """
            Respond with a JSON object of the form:
            {
              "intent": "<intent_name>",
              "params": { ... },
              "reply": "<friendly reply to speak aloud>"
            }
            Available intents: \(AssistantIntent.availableIntents)
            """
        )

        if conversationHistory.isEmpty {
            conversationHistory.append(ChatMessage(role: .system, content: systemPrompt))
        }
        conversationHistory.append(ChatMessage(role: .user, content: sanitizedMessage))

        // Try structured generation first (FoundationModels on-device, iOS 26+).
        // Falls back to nil on older OS / HTTP backends without any extra handling needed.
        if let structured = try? await backend.generateStructured(messages: conversationHistory) {
            conversationHistory.append(ChatMessage(role: .assistant, content: structured.reply))
            trimHistoryIfNeeded()

            let mapper = IntentMapper(defaultContext: dataContext)
            let intent = mapper.map(name: structured.intent, params: structured.params as [String: Any])

            var actionSucceeded = true
            var executionFeedback: String? = nil
            do {
                executionFeedback = try await intentRouter.route(intent)
            } catch {
                actionSucceeded = false
                executionFeedback = "Action failed: \(error.localizedDescription)"
            }

            let finalText = [structured.reply, executionFeedback].compactMap { $0 }.joined(separator: "\n")
            return AssistantResponse(text: finalText, intent: intent, actionSucceeded: actionSucceeded)
        }

        // Fallback: plain text chat + JSON parsing
        let rawResponse: String
        do {
            rawResponse = try await backend.chat(messages: conversationHistory)
        } catch {
            return AssistantResponse(
                text: "I had trouble reaching the local model: \(error.localizedDescription)",
                actionSucceeded: false
            )
        }

        conversationHistory.append(ChatMessage(role: .assistant, content: rawResponse))
        trimHistoryIfNeeded()

        var parsedIntent: AssistantIntent? = .unknown(rawText: rawResponse)
        var replyText = rawResponse

        if let jsonDict = try? IntentParser.extractJSON(from: rawResponse),
           let data = try? JSONSerialization.data(withJSONObject: jsonDict),
           let response = try? JSONDecoder().decode(LLMResponse.self, from: data) {
            parsedIntent = response.intent
            if let reply = response.reply {
                replyText = reply
            }
        }

        var actionSucceeded = true
        var executionFeedback: String? = nil
        do {
            if let intent = parsedIntent {
                executionFeedback = try await intentRouter.route(intent)
            }
        } catch {
            actionSucceeded = false
            executionFeedback = "Action failed: \(error.localizedDescription)"
        }

        let finalText = [replyText, executionFeedback].compactMap { $0 }.joined(separator: "\n")
        return AssistantResponse(text: finalText, intent: parsedIntent, actionSucceeded: actionSucceeded)
    }

    /// Clear conversation history (starts a new session).
    public func resetSession() {
        conversationHistory.removeAll()
    }

    /// Update the display name used in the system prompt. Resets the session so
    /// the new name takes effect immediately on the next message.
    public func setUserName(_ name: String) {
        guard !name.isEmpty, name != userName else { return }
        userName = name
        conversationHistory.removeAll()
    }

    // MARK: - Private parsing helpers

    /// Drop the oldest user/assistant pairs when history exceeds the cap,
    /// always keeping the system prompt at index 0.
    private func trimHistoryIfNeeded() {
        // conversationHistory[0] is the system message; everything after is turns.
        guard conversationHistory.count > maxHistoryMessages + 1 else { return }
        let systemMessage = conversationHistory[0]
        let recentMessages = conversationHistory.suffix(maxHistoryMessages)
        conversationHistory = [systemMessage] + Array(recentMessages)
    }
}

// MARK: - LLMResponse

private struct LLMResponse: Decodable {
    let intent: AssistantIntent?
    let reply: String?
}

// MARK: - IntentMapper

/// Maps raw model intent names and parameter dictionaries to typed `AssistantIntent` values.
///
/// Kept internal for unit tests and compatibility with existing parser-focused tests.
struct IntentMapper {
    let defaultContext: DataContext

    func map(name: String, params: [String: Any]) -> AssistantIntent {
        switch name {
        case "makeCall":
            return .makeCall(
                phoneNumber: params["phoneNumber"] as? String ?? "",
                contactName: params["contactName"] as? String
            )
        case "screenCall":
            return .screenCall(phoneNumber: params["phoneNumber"] as? String ?? "")
        case "endCall":
            return .endCall
        case "sendMessage":
            return .sendMessage(
                to: params["to"] as? String ?? "",
                body: params["body"] as? String ?? ""
            )
        case "readMessages":
            return .readMessages(from: params["sender"] as? String ?? params["from"] as? String)
        case "controlDevice":
            let action = HomeAction(rawValue: params["action"] as? String ?? "") ?? .turnOn
            return .controlDevice(
                deviceName: params["deviceName"] as? String ?? "",
                action: action
            )
        case "runScene":
            return .runScene(sceneName: params["sceneName"] as? String ?? "")
        case "queryDevice":
            return .queryDevice(deviceName: params["deviceName"] as? String ?? "")
        case "createReminder":
            let ctx = DataContext(rawValue: params["context"] as? String ?? "") ?? defaultContext
            var dueDate: Date? = nil
            if let iso = params["dueDate"] as? String {
                dueDate = ISO8601DateFormatter().date(from: iso)
            }
            return .createReminder(
                title: params["title"] as? String ?? "",
                dueDate: dueDate,
                notes: params["notes"] as? String,
                context: ctx
            )
        case "listReminders":
            let ctx = DataContext(rawValue: params["context"] as? String ?? "") ?? defaultContext
            return .listReminders(context: ctx)
        case "completeReminder":
            return .completeReminder(id: params["id"] as? String ?? "")
        case "createEvent":
            let iso = ISO8601DateFormatter()
            let now = Date()
            let start = (params["start"] as? String).flatMap { iso.date(from: $0) } ?? now
            let end   = (params["end"]   as? String).flatMap { iso.date(from: $0) } ?? start.addingTimeInterval(3600)
            return .createEvent(
                title:    params["title"]    as? String ?? "",
                start:    start,
                end:      end,
                notes:    params["notes"]    as? String,
                location: params["location"] as? String
            )
        case "listEvents":
            let iso = ISO8601DateFormatter()
            let from = (params["from"] as? String).flatMap { iso.date(from: $0) } ?? Date()
            let to   = (params["to"]   as? String).flatMap { iso.date(from: $0) } ?? from.addingTimeInterval(7 * 86400)
            return .listEvents(from: from, to: to)
        case "deleteEvent":
            return .deleteEvent(id: params["id"] as? String ?? "")
        case "browseWeb":
            return .browseWeb(query: params["query"] as? String ?? "")
        case "storeMemory":
            let ctx = DataContext(rawValue: params["context"] as? String ?? "") ?? defaultContext
            return .storeMemory(content: params["content"] as? String ?? "", context: ctx)
        case "recallMemory":
            let ctx = DataContext(rawValue: params["context"] as? String ?? "") ?? defaultContext
            return .recallMemory(query: params["query"] as? String ?? "", context: ctx)
        default:
            return .unknown(rawText: name)
        }
    }
}

// MARK: - IntentRouter

final class IntentRouter: Sendable {
    private let handlers: [IntentHandler]

    init(handlers: [IntentHandler]) {
        self.handlers = handlers
    }

    func route(_ intent: AssistantIntent) async throws -> String? {
        for handler in handlers where handler.canHandle(intent) {
            return try await handler.handle(intent)
        }
        return nil
    }
}

private func sanitizeInput(_ input: String) -> String {
    return input.replacingOccurrences(of: "<script>.*?</script>", with: "", options: .regularExpression, range: nil)
}
