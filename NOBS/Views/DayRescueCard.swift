import SwiftUI

struct DayRescueCard: View {
    let state: DayRescueState
    let onAction: (DayRescueAction) -> Void

    private let accent = Color.nobsAccent
    private let forest = Color.nobsForest
    private let warning = Color.nobsWarning
    private let surface = Color.nobsSagePale

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Rescue this day", systemImage: "lifepreserver")
                .font(.headline)
                .foregroundStyle(warning)

            Text(state.explanation)
                .font(.subheadline.weight(.medium))
                .lineSpacing(3)

            if state.conflicts.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What looks unrealistic")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                    ForEach(Array(state.conflicts.enumerated()), id: \.offset) { _, conflict in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundStyle(warning)
                            Text(conflict).font(.subheadline)
                        }
                    }
                }
            }

            if !state.recommendedPlan.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Realistic sequencing")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                    ForEach(Array(state.recommendedPlan.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundStyle(accent)
                            Text(item).font(.subheadline)
                        }
                    }
                }
            }

            Text("NOBS will not change your calendar until you confirm in chat or approve a specific change.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            VStack(spacing: 10) {
                ForEach(state.actions) { action in
                    Button {
                        onAction(action)
                    } label: {
                        HStack {
                            Text(action.label)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: actionIcon(action))
                                .foregroundStyle(forest)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(surface, in: RoundedRectangle(cornerRadius: NOBSTheme.buttonRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: NOBSTheme.buttonRadius)
                                .stroke(Color.nobsGreen.opacity(0.45), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(accessibilityHint(for: action))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: NOBSTheme.cardRadius)
                .fill(surface)
                .overlay(
                    RoundedRectangle(cornerRadius: NOBSTheme.cardRadius)
                        .stroke(warning.opacity(0.35), lineWidth: 1.5)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rescue this day")
    }

    private func actionIcon(_ action: DayRescueAction) -> String {
        switch action.kind {
        case .resolveOverlap: "arrow.left.arrow.right"
        case .chatPrompt: "bubble.left"
        }
    }

    private func accessibilityHint(for action: DayRescueAction) -> String {
        switch action.kind {
        case .resolveOverlap:
            "Opens overlap choices without changing your calendar"
        case .chatPrompt:
            "Opens chat with a prefilled rescue prompt"
        }
    }
}

#Preview {
    DayRescueCard(
        state: DayRescueState(
            explanation: "Your calendar has 8 events, which signals potential overload.",
            conflicts: [
                "Your calendar has 8 events, which signals potential overload.",
                "1 overlap needs a clear attendance decision.",
            ],
            recommendedPlan: [
                "Prepare for Team sync before 10:00 AM.",
                "Re-check afternoon priorities after lunch and defer low-impact work.",
            ],
            actions: [
                DayRescueAction(id: "resolve", label: "Pick must-attend meeting", kind: .resolveOverlap),
                DayRescueAction(
                    id: "chat",
                    label: "Draft a short conflict message",
                    kind: .chatPrompt("Help me draft a message about moving a meeting.")
                ),
            ]
        ),
        onAction: { _ in }
    )
    .padding()
    .background(Color.nobsCanvas)
}
