/// IntentHandler — protocol that all NOBS capability modules implement.
///
/// Defined in NOBSCore so every module can conform without importing NOBSAssistant.

import Foundation

/// Any module that can execute an `AssistantIntent` implements this protocol.
public protocol IntentHandler: Sendable {
    /// Returns `true` if this handler can service the given intent.
    func canHandle(_ intent: AssistantIntent) -> Bool

    /// Execute the intent and return a human-readable result string.
    func handle(_ intent: AssistantIntent) async throws -> String
}
