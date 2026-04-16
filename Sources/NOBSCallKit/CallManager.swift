/// NOBSCallKit — Phone Calls and Call Screening
///
/// Wraps Apple's CallKit framework to:
///   • Place outbound calls programmatically.
///   • Screen inbound calls from numbers not in the user's contacts.
///   • Integrate with Google Voice via `NOBSVoice` for carrier-independent calling.
///
/// Required entitlements: com.apple.developer.callkit
///
/// On non-iOS/macOS platforms (e.g. Linux CI) the CallKit import is guarded
/// so that the module still compiles for tests.

import Foundation

#if canImport(CallKit)
import CallKit
#endif

import NOBSCore
import NOBSDatabase

// MARK: - CallError

public enum CallError: Error, LocalizedError, Sendable {
    case invalidPhoneNumber(String)
    case callKitNotAvailable
    case callFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber(let n):  return "Invalid phone number: \(n)"
        case .callKitNotAvailable:        return "CallKit is not available on this device"
        case .callFailed(let reason):     return "Call failed: \(reason)"
        }
    }
}

// MARK: - CallRecord

/// An on-device record of a placed or received call.
public struct CallRecord: Sendable {
    public let id: UUID
    public let phoneNumber: String
    public let contactName: String?
    public let direction: Direction
    public let outcome: Outcome
    public let startedAt: Date
    public let duration: TimeInterval

    public enum Direction: String, Sendable { case outbound, inbound }
    public enum Outcome:   String, Sendable { case connected, missed, declined, screened }

    public init(
        id: UUID = UUID(),
        phoneNumber: String,
        contactName: String? = nil,
        direction: Direction,
        outcome: Outcome,
        startedAt: Date = Date(),
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.contactName = contactName
        self.direction = direction
        self.outcome = outcome
        self.startedAt = startedAt
        self.duration = duration
    }
}

// MARK: - ScreeningDecision

/// The decision the assistant makes about an incoming unknown call.
public enum ScreeningDecision: String, Sendable {
    /// Allow the call through to ring normally.
    case allow
    /// Silence the ringer but let the call go to voicemail.
    case silence
    /// Answer and ask the caller to identify themselves.
    case askForName
    /// Reject the call immediately (spam / blocked).
    case reject
}

// MARK: - CallScreener

/// Decides what to do with an incoming call based on contact lookup.
public struct CallScreener: Sendable {
    private let knownContactNumbers: Set<String>
    private let blockedNumbers: Set<String>

    public init(knownContactNumbers: Set<String> = [], blockedNumbers: Set<String> = []) {
        self.knownContactNumbers = knownContactNumbers
        self.blockedNumbers = blockedNumbers
    }

    /// Evaluate an incoming call and return a screening decision.
    public func evaluate(phoneNumber: String, callerName: String?) -> ScreeningDecision {
        let normalised = normalise(phoneNumber)
        if blockedNumbers.contains(normalised)       { return .reject }
        if knownContactNumbers.contains(normalised)  { return .allow }
        if callerName != nil                          { return .silence }
        return .askForName
    }

    private func normalise(_ number: String) -> String {
        number.filter(\.isNumber)
    }
}

// MARK: - CallManager

/// High-level manager for placing and managing calls.
///
/// On iOS / macOS this wraps `CXCallController`.
/// On other platforms (Linux tests) it falls back to stubs.
public actor CallManager: IntentHandler {
#if canImport(CallKit)
    private let callController = CXCallController()
#endif
    private var activeCallID: UUID?
    public private(set) var callHistory: [CallRecord] = []

    public init() {}

    // MARK: IntentHandler

    public nonisolated func canHandle(_ intent: AssistantIntent) -> Bool {
        switch intent {
        case .makeCall, .screenCall, .endCall: return true
        default: return false
        }
    }

    public func handle(_ intent: AssistantIntent) async throws -> String {
        switch intent {
        case .makeCall(let number, let name):
            try await place(call: number, displayName: name)
            return "Calling \(name ?? number)…"
        case .screenCall(let number):
            let decision = CallScreener().evaluate(phoneNumber: number, callerName: nil)
            return "Screen decision for \(number): \(decision.rawValue)"
        case .endCall:
            try await end()
            return "Call ended."
        default:
            throw CallError.callFailed("Unhandled intent")
        }
    }

    // MARK: - Placing calls

    /// Request CallKit to place an outbound call.
    public func place(call phoneNumber: String, displayName: String? = nil) async throws {
        guard !phoneNumber.filter(\.isNumber).isEmpty else {
            throw CallError.invalidPhoneNumber(phoneNumber)
        }

#if canImport(CallKit)
        let handle = CXHandle(type: .phoneNumber, value: phoneNumber)
        let uuid   = UUID()
        activeCallID = uuid
        let action = CXStartCallAction(call: uuid, handle: handle)
        action.isVideo = false
        if let name = displayName { action.contactIdentifier = name }
        let transaction = CXTransaction(action: action)
        try await callController.request(transaction)
#else
        activeCallID = UUID()
#endif
    }

    /// End the currently active call.
    public func end() async throws {
        guard let uuid = activeCallID else { return }
#if canImport(CallKit)
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        try await callController.request(transaction)
#endif
        activeCallID = nil
    }

    /// Record a completed call for auditing.
    public func record(_ record: CallRecord) {
        callHistory.append(record)
    }
}

// MARK: - CallDirectoryHandler documentation

/// Documents how to create the Call Directory Extension.
///
/// Steps:
///   1. In Xcode: File → New → Target → Call Directory Extension
///   2. Set the principal class to a `CXCallDirectoryProvider` subclass.
///   3. In `beginRequest(with:)`:
///      - Fetch blocked numbers from `NOBSDatabase` and call
///        `context.addBlockingEntry(withNextSequentialPhoneNumber:)`
///      - Fetch labelled numbers from `NOBSDatabase` and call
///        `context.addIdentificationEntry(withNextSequentialPhoneNumber:label:)`
///   4. Call `context.completeRequest()`
public enum CallDirectoryHandlerGuide {
    public static let setupInstructions = """
    1. Add a Call Directory Extension target in Xcode.
    2. Subclass CXCallDirectoryProvider.
    3. Fetch blocked/labelled numbers from NOBSDatabase.
    4. Register them with the CXCallDirectoryExtensionContext.
    5. Call context.completeRequest().
    """
}
