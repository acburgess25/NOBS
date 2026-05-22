/// EmptyStateView — Reusable empty-list placeholder
///
/// Centered warm empty state with icon, title, subtitle, and an optional
/// primary action button. Matches the NOBS amber + sage aesthetic.
/// Drop into any list .overlay { } or NavigationStack body.

import SwiftUI

// MARK: - EmptyStateView

struct EmptyStateView: View {

    // MARK: Props

    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    // MARK: Body

    var body: some View {
        VStack(spacing: Spacing.lg) {
            iconBadge
            textStack
            if let label = actionLabel, let onTap = action {
                NOBSButton(
                    label: label,
                    style: .primary,
                    size: .medium,
                    fullWidth: false,
                    action: onTap
                )
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Subviews

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(Color.nobsAccent.opacity(0.12))
                .frame(width: 96, height: 96)
            Image(systemName: icon)
                .font(.system(size: 40, weight: .medium, design: .rounded))
                .foregroundStyle(Color.nobsAccent)
        }
    }

    private var textStack: some View {
        VStack(spacing: Spacing.sm) {
            Text(title)
                .font(NOBSFont.title3())
                .foregroundStyle(Color.nobsPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(NOBSFont.body())
                .foregroundStyle(Color.nobsSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        Color.nobsBg.ignoresSafeArea()
        EmptyStateView(
            icon: "checklist",
            title: "No Tasks Yet",
            subtitle: "Add your first task above. Tasks are stored locally and synced on demand.",
            action: {},
            actionLabel: "Add Task"
        )
    }
}
#endif
