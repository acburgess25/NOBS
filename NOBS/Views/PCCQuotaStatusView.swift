import SwiftUI

struct PCCQuotaStatusView: View {
    let quota: PCCQuotaStatus
    var onShowUpgradeOptions: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if quota.isLimitReached {
                Label("Apple private cloud daily limit reached", systemImage: "exclamationmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.nobsDestructive)
            } else if quota.isApproachingLimit {
                Label("Nearing Apple private cloud daily limit", systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if let statusMessage = quota.statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if quota.isLimitReached || quota.isApproachingLimit, let onShowUpgradeOptions {
                Button("Show iCloud+ options") {
                    onShowUpgradeOptions()
                }
                .font(.caption.weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
    }
}
