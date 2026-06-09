import SwiftUI

// MARK: - EmptyStateView
//
// Minimal, stock-SwiftUI placeholder shown when a list/section has nothing in
// it yet. Custom brand styling (Color.nobsAccent / NOBSFont / Spacing) can be
// re-added once those types are confirmed to compile in this target — this
// version intentionally uses only standard SwiftUI to stay buildable.

struct EmptyStateView: View {

    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    @State private var isIconVisible = false

    var body: some View {
        VStack(spacing: 20) {
            iconBadge
                .opacity(isIconVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: isIconVisible)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let label = actionLabel, let onTap = action {
                Button(label) { onTap() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(subtitle)")
        .onAppear {
            isIconVisible = true
        }
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(Color.nobsSecondary.opacity(0.12))
                .frame(width: 96, height: 96)
            Image(systemName: icon)
                .font(.system(size: 40, weight: .medium, design: .rounded))
                .foregroundStyle(Color.nobsAccent)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Tasks") {
    EmptyStateView(
        icon: "checklist",
        title: "No Tasks Yet",
        subtitle: "Add your first task above. Tasks are stored locally and synced on demand.",
        action: {},
        actionLabel: "Add Task"
    )
}

#Preview("Favorites") {
    EmptyStateView(
        icon: "heart",
        title: "No Favorites Yet",
        subtitle: "Tap the heart on any item to save it here.",
        action: {},
        actionLabel: "Browse"
    )
}

#Preview("No action") {
    EmptyStateView(
        icon: "tray",
        title: "Inbox is empty",
        subtitle: "You're all caught up."
    )
}
#endif
