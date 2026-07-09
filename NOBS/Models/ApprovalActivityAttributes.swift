import ActivityKit
import Foundation

/// Shared between the NOBS app (starts/updates/ends the activity) and the
/// NOBSWidgets extension (renders it). Keep this file dependency-free
/// (no AnyCodable, no app-only services) so it compiles in both targets.
struct ApprovalActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var approvalId: String
        var toolName: String
        var reasonSummary: String
        var risk: String
        var pendingCount: Int
        var createdAt: Date
    }

    var startedAt: Date
}
