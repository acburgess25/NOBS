import ActivityKit
import Foundation

/// Starts, updates, and ends the Lock Screen / Dynamic Island Live Activity
/// for a pending Tank agent approval. Approval execution itself always goes
/// through `AppModel.decideApproval` / `TankClient` — this type only manages
/// the ActivityKit lifecycle from the data `AppModel` already fetched.
@MainActor
final class ApprovalActivityManager {
    // `Activity` is Sendable, but Swift's region checker still ties a value
    // read from a MainActor-isolated stored property to the actor's region,
    // which trips strict concurrency checking when handed to ActivityKit's
    // `@concurrent` update/end methods below. All mutations to this property
    // already happen exclusively from this @MainActor type, so opting the
    // property itself out of isolation checking is safe here.
    private nonisolated(unsafe) var currentActivity: Activity<ApprovalActivityAttributes>?

    /// Reattach to an activity that is still on screen from a previous app
    /// launch (Live Activities can outlive the process that started them).
    func reconnectIfNeeded() {
        guard currentActivity == nil else { return }
        currentActivity = Activity<ApprovalActivityAttributes>.activities.first
    }

    /// Reconciles the Live Activity with the current set of approvals.
    /// Starts one when the first pending approval appears, updates it when
    /// the latest approval or pending count changes, and ends it once
    /// nothing is left pending.
    func sync(with approvals: [PendingApproval]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let pending = approvals.filter { $0.status == "pending" }
        guard let latest = latestApproval(in: pending) else {
            await endActivity()
            return
        }

        let state = contentState(for: latest, pendingCount: pending.count)

        if let activity = currentActivity {
            guard activity.content.state != state else { return }
            await activity.update(ActivityContent(state: state, staleDate: nil))
        } else {
            do {
                currentActivity = try Activity<ApprovalActivityAttributes>.request(
                    attributes: ApprovalActivityAttributes(startedAt: Date()),
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
            } catch {
                // Live Activities may be unavailable (Low Power Mode, user
                // disabled them, or the OS denied the request). Approvals
                // remain fully visible and actionable in the app either way.
            }
        }
    }

    /// Ends the current activity immediately, e.g. once every approval is
    /// decided or Tank is signed out of.
    func endActivity() async {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    private func latestApproval(in approvals: [PendingApproval]) -> PendingApproval? {
        approvals.max { lhs, rhs in
            (isoDate(lhs.createdAt) ?? .distantPast) < (isoDate(rhs.createdAt) ?? .distantPast)
        }
    }

    private func contentState(
        for approval: PendingApproval,
        pendingCount: Int
    ) -> ApprovalActivityAttributes.ContentState {
        ApprovalActivityAttributes.ContentState(
            approvalId: approval.id,
            toolName: approval.toolName,
            reasonSummary: String(approval.reason.prefix(140)),
            risk: approval.risk,
            pendingCount: pendingCount,
            createdAt: isoDate(approval.createdAt) ?? Date()
        )
    }

    private func isoDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
