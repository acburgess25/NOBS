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
    private let modelClient: ModelClient
    private let intentRouter: IntentRouter
    private var conversationHistory: [ChatMessage] = []
    private let userName: String
    private let dataContext: DataContext

    /// Maximum number of non-system messages kept in the conversation window.
    ///
    /// When the history grows beyond this limit the oldest user/assistant pairs
    /// are dropped while the system prompt is always preserved.  This prevents
    /// unbounded memory growth and keeps requests within the model's token limit.
    public let maxHistoryMessages: Int

    /// - Parameters:
    ///   - config: Configuration for the local LLM.
    ///   - handlers: Module handlers that service intents.
    ///   - userName: Name used to personalise the system prompt.
    ///   - dataContext: Whether the session is personal or work.
    ///   - maxHistoryMessages: Maximum number of non-system messages to keep in
    ///     the conversation window. Defaults to 40 (20 turns). Older messages are
    ///     dropped automatically to prevent token-limit and memory issues.
    public init(
        config: ModelConfiguration,
        handlers: [IntentHandler] = [],
        userName: String = "User",
        dataContext: DataContext = .personal,
        maxHistoryMessages: Int = 40
    ) {
        self.modelClient = ModelClient(config: config)
        self.intentRouter = IntentRouter(handlers: handlers)
        self.userName = userName
        self.dataContext = dataContext
        self.maxHistoryMessages = max(2, maxHistoryMessages)
    }

    // MARK: - Public API

    /// Process a natural-language user message and return the assistant response.
    public func process(_ userMessage: String) async -> AssistantResponse {
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
            Available intents: makeCall, sendMessage, controlDevice, runScene,
            createReminder, listReminders, browseWeb, storeMemory, recallMemory, unknown.
            """
        )

        if conversationHistory.isEmpty {
            conversationHistory.append(ChatMessage(role: .system, content: systemPrompt))
        }
        conversationHistory.append(ChatMessage(role: .user, content: userMessage))

        let rawResponse: String
        do {
            rawResponse = try await modelClient.chat(messages: conversationHistory)
        } catch {
            return AssistantResponse(
                text: "I had trouble reaching the local model: \(error.localizedDescription)",
                actionSucceeded: false
            )
        }

        conversationHistory.append(ChatMessage(role: .assistant, content: rawResponse))
        trimHistoryIfNeeded()

        let intent = parseIntent(from: rawResponse)
        let replyText = extractReply(from: rawResponse) ?? rawResponse

        var actionSucceeded = true
        var executionFeedback: String? = nil
        do {
            executionFeedback = try await intentRouter.route(intent)
        } catch {
            actionSucceeded = false
            executionFeedback = "Action failed: \(error.localizedDescription)"
        }

        let finalText = [replyText, executionFeedback].compactMap { $0 }.joined(separator: "\n")
        return AssistantResponse(text: finalText, intent: intent, actionSucceeded: actionSucceeded)
    }

    /// Clear conversation history (starts a new session).
    public func resetSession() {
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

    private func parseIntent(from text: String) -> AssistantIntent {
        guard let json = try? IntentParser.extractJSON(from: text),
              let intentName = json["intent"] as? String else {
            return .unknown(rawText: text)
        }
        let params = json["params"] as? [String: Any] ?? [:]
        return mapIntent(name: intentName, params: params)
    }

    private func extractReply(from text: String) -> String? {
        guard let json = try? IntentParser.extractJSON(from: text) else { return nil }
        return json["reply"] as? String
    }

    private func mapIntent(name: String, params: [String: Any]) -> AssistantIntent {
        switch name {
        case "makeCall":
            return .makeCall(
                phoneNumber: params["phoneNumber"] as? String ?? "",
                contactName: params["contactName"] as? String
            )
        case "sendMessage":
            return .sendMessage(
                to:   params["to"]   as? String ?? "",
                body: params["body"] as? String ?? ""
            )
        case "controlDevice":
            let action = HomeAction(rawValue: params["action"] as? String ?? "") ?? .turnOn
            return .controlDevice(
                deviceName: params["deviceName"] as? String ?? "",
                action: action
            )
        case "runScene":
            return .runScene(sceneName: params["sceneName"] as? String ?? "")
        case "createReminder":
            let ctx = DataContext(rawValue: params["context"] as? String ?? "") ?? dataContext
            var dueDate: Date? = nil
            if let iso = params["dueDate"] as? String {
                dueDate = ISO8601DateFormatter().date(from: iso)
            }
            return .createReminder(
                title:   params["title"]   as? String ?? "",
                dueDate: dueDate,
                notes:   params["notes"]   as? String,
                context: ctx
            )
        case "listReminders":
            let ctx = DataContext(rawValue: params["context"] as? String ?? "") ?? dataContext
            return .listReminders(context: ctx)
        case "browseWeb":
            return .browseWeb(query: params["query"] as? String ?? "")
        case "storeMemory":
            let ctx = DataContext(rawValue: params["context"] as? String ?? "") ?? dataContext
            return .storeMemory(content: params["content"] as? String ?? "", context: ctx)
        case "recallMemory":
            let ctx = DataContext(rawValue: params["context"] as? String ?? "") ?? dataContext
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
