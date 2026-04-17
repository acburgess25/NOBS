/// NOBSiMessage — iMessage Integration
///
/// Provides two integration surfaces:
///
/// 1. **Inbound**: A Share / Notification extension that forwards incoming
///    iMessages to the NOBS assistant for processing.
/// 2. **Outbound**: Sends replies via the `sms:` URL scheme on iOS or
///    `NSWorkspace` on macOS.
///
/// Privacy: All conversation history is stored locally in NOBSDatabase.
///          Nothing leaves the device.
///
/// Required: iMessage App Extension entitlement.

import Foundation

#if canImport(Messages)
import Messages
#endif

import NOBSCore
import NOBSDatabase

// MARK: - MessageRecord

/// An on-device record of a single iMessage turn.
public struct MessageRecord: Sendable {
    public let id: UUID
    public let sender: String
    public let body: String
    public let receivedAt: Date
    public let isOutbound: Bool
    public let dataContext: DataContext

    public init(
        id: UUID = UUID(),
        sender: String,
        body: String,
        receivedAt: Date = Date(),
        isOutbound: Bool = false,
        dataContext: DataContext = .personal
    ) {
        self.id = id
        self.sender = sender
        self.body = body
        self.receivedAt = receivedAt
        self.isOutbound = isOutbound
        self.dataContext = dataContext
    }
}

// MARK: - ConversationHistory

/// Stores and retrieves per-contact message history in NOBSDatabase.
public actor ConversationHistory {
    private let repository: MemoryRepository

    public init(dataContext: DataContext, database: NOBSDatabase = .shared) {
        self.repository = MemoryRepository(context: dataContext, database: database)
    }

    /// Append a message to the on-device history.
    public func append(_ message: MessageRecord) throws {
        let direction = message.isOutbound ? "→" : "←"
        let content   = "[\(direction) \(message.sender)] \(message.body)"
        try repository.save(content: content, tags: ["imessage", message.sender])
    }

    /// Retrieve recent messages from / to a contact.
    public func messages(from sender: String) throws -> [MemoryMO] {
        try repository.search(query: sender)
    }
}

// MARK: - iMessageHandler

/// Handles messaging intents dispatched by `NOBSAssistant`.
public actor iMessageHandler: IntentHandler {
    private let history: ConversationHistory

    public init(dataContext: DataContext = .personal, database: NOBSDatabase = .shared) {
        self.history = ConversationHistory(dataContext: dataContext, database: database)
    }

    // MARK: IntentHandler

    public nonisolated func canHandle(_ intent: AssistantIntent) -> Bool {
        switch intent {
        case .sendMessage, .readMessages: return true
        default: return false
        }
    }

    public func handle(_ intent: AssistantIntent) async throws -> String {
        switch intent {
        case .sendMessage(let to, let body):
            return try await send(to: to, body: body)
        case .readMessages(let sender):
            return try await readHistory(from: sender)
        default:
            throw iMessageError.unsupportedIntent
        }
    }

    // MARK: - Sending

    /// Compose and queue an iMessage.
    ///
    /// Records the outbound message locally, then returns the `sms:` URL the
    /// app layer should open with `UIApplication.shared.open(url)` on iOS or
    /// `NSWorkspace.shared.open(url)` on macOS.
    ///
    /// - Returns: A human-readable confirmation that also embeds the `sms:` URL.
    public func send(to recipient: String, body: String) async throws -> String {
        let record = MessageRecord(sender: recipient, body: body, isOutbound: true)
        try await history.append(record)

        if let url = iMessageHandler.composeURL(to: recipient, body: body) {
            return "Message queued for \(recipient). Open URL to send: \(url.absoluteString)"
        }
        return "Message queued for \(recipient)."
    }

    /// Build the `sms:` URL the app layer must open to deliver the message.
    ///
    /// Returns `nil` if either the recipient or the percent-encoded body cannot
    /// form a valid URL.
    public static func composeURL(to recipient: String, body: String) -> URL? {
        guard let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !recipient.isEmpty else { return nil }
        return URL(string: "sms:\(recipient)?body=\(encoded)")
    }

    // MARK: - Reading

    public func readHistory(from sender: String?) async throws -> String {
        guard let sender else { return "Please specify a contact to read messages from." }
        let memories = try await history.messages(from: sender)
        if memories.isEmpty { return "No message history with \(sender)." }
        return memories.map(\.content).joined(separator: "\n")
    }
}

// MARK: - Errors

public enum iMessageError: Error, LocalizedError, Sendable {
    case unsupportedIntent
    case sendFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedIntent:      return "iMessageHandler received an unsupported intent"
        case .sendFailed(let reason): return "Message send failed: \(reason)"
        }
    }
}

// MARK: - iMessage Extension Guidance

/// Documents how to wire up the iMessage App Extension.
public enum iMessageExtensionGuide {
    public static let setupInstructions = """
    1. File → New → Target → iMessage Extension
    2. Override MSMessagesAppViewController.didReceive(_:conversation:)
    3. Extract message.body and pass it to NOBSAssistant.process()
    4. Construct an MSMessage from the response and call conversation.insert(_:)
    """
}
