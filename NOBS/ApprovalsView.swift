import SwiftUI

// MARK: - Main Approvals View

struct ApprovalsView: View {
    @EnvironmentObject private var model: AppModel

    private let accent = Color.nobsAccent
    private let canvas = Color.nobsCanvas

    @State private var segment: Segment = .approvals

    enum Segment: String, CaseIterable {
        case approvals = "Approvals"
        case proposals = "Proposals"
    }

    var body: some View {
        VStack(spacing: 0) {
            segmentPicker
            Divider()
            ScrollView {
                LazyVStack(spacing: 14) {
                    switch segment {
                    case .approvals: approvalsContent
                    case .proposals: proposalsContent
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
        }
        .background(canvas.ignoresSafeArea())
        .task { await refresh() }
    }

    // MARK: Segment picker

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(Segment.allCases, id: \.self) { seg in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { segment = seg }
                } label: {
                    HStack(spacing: 6) {
                        Text(seg.rawValue)
                            .font(.subheadline.weight(segment == seg ? .semibold : .regular))
                        if let badge = badgeCount(for: seg), badge > 0 {
                            Text("\(badge)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accent, in: Capsule())
                        }
                    }
                    .foregroundStyle(segment == seg ? accent : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        if segment == seg {
                            Rectangle()
                                .fill(accent)
                                .frame(height: 2)
                                .padding(.horizontal, 18)
                        }
                    }
                }
                .accessibilityAddTraits(segment == seg ? .isSelected : [])
            }
        }
        .background(canvas)
    }

    private func badgeCount(for seg: Segment) -> Int? {
        switch seg {
        case .approvals: return model.approvals.filter { $0.status == "pending" }.count
        case .proposals: return model.proposals.filter { $0.status == "pending" }.count
        }
    }

    // MARK: Approvals content

    @ViewBuilder
    private var approvalsContent: some View {
        if model.approvalsFetchState == .idle || (model.isLoadingApprovals && model.approvals.isEmpty) {
            loadingView("Checking Tank for pending approvals…")
        } else if model.approvalsFetchState == .unavailable {
            emptyState(
                symbol: "checkmark.shield",
                title: "Tank is offline",
                detail: "Reconnect Tank to see pending approvals."
            )
        } else if let message = model.approvalsFetchState.errorMessage {
            errorState(message: message) {
                Task { await model.loadApprovals() }
            }
        } else if model.approvals.filter({ $0.status == "pending" }).isEmpty {
            emptyState(
                symbol: "checkmark.shield",
                title: "No pending approvals",
                detail: "Tank has no tool actions waiting on your decision."
            )
        } else {
            ForEach(model.approvals.filter { $0.status == "pending" }) { approval in
                ApprovalCard(approval: approval, accent: accent) { decision in
                    Task { await model.decideApproval(approval, decision: decision) }
                }
            }
        }
        refreshButton(action: { Task { await model.loadApprovals() } }, loading: model.isLoadingApprovals)
    }

    // MARK: Proposals content

    @ViewBuilder
    private var proposalsContent: some View {
        if model.proposalsFetchState == .idle || (model.isLoadingProposals && model.proposals.isEmpty) {
            loadingView("Checking Tank for proposals…")
        } else if model.proposalsFetchState == .unavailable {
            emptyState(
                symbol: "lightbulb",
                title: "Tank is offline",
                detail: "Reconnect Tank to see proposals from the agent."
            )
        } else if let message = model.proposalsFetchState.errorMessage {
            errorState(message: message) {
                Task { await model.loadProposals() }
            }
        } else if model.proposals.filter({ $0.status == "pending" }).isEmpty {
            emptyState(
                symbol: "lightbulb",
                title: "No pending proposals",
                detail: "Tank has no new ideas waiting for your approval."
            )
        } else {
            ForEach(model.proposals.filter { $0.status == "pending" }) { proposal in
                ProposalCard(proposal: proposal, accent: accent) { decision in
                    Task { await model.decideProposal(proposal, decision: decision) }
                }
            }
        }
        refreshButton(action: { Task { await model.loadProposals() } }, loading: model.isLoadingProposals)
    }

    // MARK: Shared helpers

    private func loadingView(_ message: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(message).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
    }

    private func emptyState(symbol: String, title: String, detail: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: symbol,
            description: Text(detail)
        )
        .padding(.top, 30)
    }

    private func errorState(message: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ContentUnavailableView(
                "Could not load",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
                .tint(accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.top, 30)
    }

    private func refreshButton(action: @escaping () -> Void, loading: Bool) -> some View {
        Button(action: action) {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .tint(accent)
        .disabled(loading)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 4)
    }

    private func refresh() async {
        await model.loadApprovals()
        await model.loadProposals()
    }
}

// MARK: - Approval Card

private struct ApprovalCard: View {
    let approval: PendingApproval
    let accent: Color
    let onDecide: (String) -> Void

    @State private var showArguments = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: toolIcon(for: approval.toolName))
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 32, height: 32)
                    .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(approval.toolName.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.headline)
                    RiskBadge(risk: approval.risk)
                }
                Spacer()
            }

            // Reason
            Text(approval.reason)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            // Arguments disclosure
            if !approval.arguments.isEmpty {
                // TODO(feature): Expand approval details with richer argument formatting and full execution context.
                DisclosureGroup(isExpanded: $showArguments) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(approval.arguments.keys.sorted()), id: \.self) { key in
                            HStack(alignment: .top, spacing: 8) {
                                Text(key)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 100, alignment: .leading)
                                Text(approval.arguments[key]?.displayString ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Arguments (\(approval.arguments.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                }
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onDecide("deny")
                } label: {
                    Label("Deny", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    onDecide("approve")
                } label: {
                    Label("Approve", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
            .controlSize(.regular)
        }
        .padding(18)
        .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(riskColor(for: approval.risk).opacity(0.25), lineWidth: 1.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Approval request: \(approval.toolName). Risk: \(approval.risk). \(approval.reason)")
    }

    private func toolIcon(for toolName: String) -> String {
        switch toolName {
        case let n where n.contains("web_search"): return "magnifyingglass"
        case let n where n.contains("weather"): return "cloud.sun"
        case let n where n.contains("news"): return "newspaper"
        case let n where n.contains("url") || n.contains("read"): return "link"
        case let n where n.contains("wikipedia"): return "books.vertical"
        case let n where n.contains("file") || n.contains("project"): return "folder"
        case let n where n.contains("status"): return "server.rack"
        case let n where n.contains("home") || n.contains("assistant"): return "house"
        default: return "gearshape"
        }
    }
}

// MARK: - Proposal Card

private struct ProposalCard: View {
    let proposal: AgentProposal
    let accent: Color
    let onDecide: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: proposalIcon(for: proposal.proposalType))
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 32, height: 32)
                    .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(proposal.title)
                        .font(.headline)
                    ProposalTypeBadge(type: proposal.proposalType, accent: accent)
                }
                Spacer()
            }

            // Description
            Text(proposal.description)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            // Timestamp
            if let date = isoDate(proposal.createdAt) {
                Text("Proposed \(date.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onDecide("dismiss")
                } label: {
                    Label("Dismiss", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button {
                    onDecide("approve")
                } label: {
                    Label("Approve", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
            .controlSize(.regular)
        }
        .padding(18)
        .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accent.opacity(0.2), lineWidth: 1.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Proposal: \(proposal.title). \(proposal.description)")
    }

    private func proposalIcon(for type: String) -> String {
        switch type {
        case "automation": return "gearshape.2"
        case "reminder": return "bell"
        case "research": return "magnifyingglass"
        case "planning": return "calendar"
        default: return "lightbulb"
        }
    }

    private func isoDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: string) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - Risk Badge

private struct RiskBadge: View {
    let risk: String

    var body: some View {
        Text(risk.capitalized)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.13), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
    }

    private var color: Color { riskColor(for: risk) }
}

// MARK: - Proposal Type Badge

private struct ProposalTypeBadge: View {
    let type: String
    let accent: Color

    var body: some View {
        Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(accent.opacity(0.1), in: Capsule())
    }
}

// MARK: - Shared helpers

private func riskColor(for risk: String) -> Color {
    switch risk.lowercased() {
    case "low": return .nobsAccent
    case "medium": return .orange
    case "high", "critical": return .red
    default: return .secondary
    }
}
