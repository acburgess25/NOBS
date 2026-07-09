import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presentation for a pending Tank approval.
/// Approve / Deny open the app via deep link rather than executing the
/// decision from the extension — approval execution stays behind the same
/// atomic, audited path `AppModel.decideApproval` already uses.
struct ApprovalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ApprovalActivityAttributes.self) { context in
            ApprovalLockScreenView(state: context.state)
                .activityBackgroundTint(Color.nobsCanvas)
                .activitySystemActionForegroundColor(Color.nobsForest)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Color.nobsAccent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RiskPill(risk: context.state.risk)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toolTitle(context.state.toolName))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.nobsInk)
                            .lineLimit(1)
                        Text(context.state.reasonSummary)
                            .font(.caption)
                            .foregroundStyle(Color.nobsMuted)
                            .lineLimit(2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ApprovalActionButtons(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Color.nobsAccent)
            } compactTrailing: {
                if context.state.pendingCount > 1 {
                    Text("\(context.state.pendingCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.nobsForest)
                } else {
                    Image(systemName: riskSymbol(context.state.risk))
                        .foregroundStyle(riskColor(context.state.risk))
                }
            } minimal: {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Color.nobsAccent)
            }
            .widgetURL(approvalURL(id: context.state.approvalId))
            .keylineTint(Color.nobsAccent)
        }
    }
}

private struct ApprovalLockScreenView: View {
    let state: ApprovalActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Color.nobsAccent)
                Text("Tank needs your approval")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.nobsForest)
                Spacer(minLength: 0)
                RiskPill(risk: state.risk)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(toolTitle(state.toolName))
                    .font(.headline)
                    .foregroundStyle(Color.nobsInk)
                    .lineLimit(1)
                Text(state.reasonSummary)
                    .font(.subheadline)
                    .foregroundStyle(Color.nobsMuted)
                    .lineLimit(2)
            }

            if state.pendingCount > 1 {
                Text("+\(state.pendingCount - 1) more waiting")
                    .font(.caption)
                    .foregroundStyle(Color.nobsMuted)
            }

            ApprovalActionButtons(state: state)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Tank needs approval for \(toolTitle(state.toolName)). Risk \(state.risk). \(state.reasonSummary)"
        )
    }
}

/// Deep-link "buttons" — Live Activities can only foreground the app via
/// `Link`/`widgetURL`, not run arbitrary code, so Approve and Deny hand off
/// to `AppModel` in the running app, which performs the actual decision.
private struct ApprovalActionButtons: View {
    let state: ApprovalActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            Link(destination: approvalURL(id: state.approvalId, action: "deny")) {
                Label("Deny", systemImage: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(.red)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Deny \(toolTitle(state.toolName))")

            Link(destination: approvalURL(id: state.approvalId, action: "approve")) {
                Label("Approve", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(Color.nobsAccent, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Approve \(toolTitle(state.toolName))")
        }
    }
}

private struct RiskPill: View {
    let risk: String

    var body: some View {
        Text(risk.capitalized)
            .font(.caption2.weight(.bold))
            .foregroundStyle(riskColor(risk))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(riskColor(risk).opacity(0.15), in: Capsule())
    }
}

private func approvalURL(id: String, action: String? = nil) -> URL {
    var components = URLComponents()
    components.scheme = "nobs"
    components.host = "approvals"
    var items = [URLQueryItem(name: "id", value: id)]
    if let action {
        items.append(URLQueryItem(name: "action", value: action))
    }
    components.queryItems = items
    return components.url ?? URL(string: "nobs://approvals")!
}

private func toolTitle(_ toolName: String) -> String {
    toolName.replacingOccurrences(of: "_", with: " ").capitalized
}

private func riskColor(_ risk: String) -> Color {
    switch risk.lowercased() {
    case "low": return .nobsAccent
    case "medium": return .nobsWarning
    case "high", "critical": return .red
    default: return .secondary
    }
}

private func riskSymbol(_ risk: String) -> String {
    switch risk.lowercased() {
    case "high", "critical": return "exclamationmark.triangle.fill"
    case "medium": return "exclamationmark.circle.fill"
    default: return "checkmark.circle.fill"
    }
}
