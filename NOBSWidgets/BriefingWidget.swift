import SwiftUI
import WidgetKit

struct BriefingWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: BriefingSnapshot?
}

struct BriefingWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BriefingWidgetEntry {
        BriefingWidgetEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (BriefingWidgetEntry) -> Void) {
        let snapshot = context.isPreview ? .sample : BriefingSnapshotReader.load()
        completion(BriefingWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BriefingWidgetEntry>) -> Void) {
        let snapshot = BriefingSnapshotReader.load()
        let entry = BriefingWidgetEntry(date: .now, snapshot: snapshot)
        let refresh = nextRefreshDate(from: snapshot?.generatedAt ?? .now, evening: snapshot?.showsEveningContext == true)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func nextRefreshDate(from generatedAt: Date, evening: Bool) -> Date {
        let calendar = Calendar.current
        let interval: TimeInterval = evening ? 20 * 60 : 30 * 60
        let thirtyMinutes = generatedAt.addingTimeInterval(interval)
        let startOfNextHour = calendar.date(
            byAdding: .hour,
            value: 1,
            to: calendar.dateInterval(of: .hour, for: Date())?.start ?? Date()
        ) ?? Date().addingTimeInterval(3600)
        let candidates = [thirtyMinutes, startOfNextHour].filter { $0 > Date() }
        return candidates.min() ?? Date().addingTimeInterval(1800)
    }
}

struct BriefingWidget: Widget {
    static let kind = AppGroupStore.briefingWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: BriefingWidgetProvider()) { entry in
            BriefingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's plan")
        .description("Your latest NOBS briefing at a glance — morning or evening.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct BriefingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BriefingWidgetEntry

    private var todayURL: URL {
        URL(string: "nobs://today")!
    }

    private var isLockScreenFamily: Bool {
        family == .accessoryRectangular
    }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(for: snapshot)
            } else {
                emptyState
            }
        }
        .widgetURL(todayURL)
    }

    @ViewBuilder
    private func content(for snapshot: BriefingSnapshot) -> some View {
        let redacted = snapshot.shouldRedactDetails(forLockScreen: isLockScreenFamily)

        switch family {
        case .systemSmall:
            smallView(snapshot: snapshot, redacted: redacted)
        case .systemMedium:
            mediumView(snapshot: snapshot, redacted: redacted)
        case .accessoryRectangular:
            lockScreenView(snapshot: snapshot, redacted: redacted)
        default:
            smallView(snapshot: snapshot, redacted: redacted)
        }
    }

    private func smallView(snapshot: BriefingSnapshot, redacted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(for: snapshot)
            if snapshot.showsEveningContext, let evening = snapshot.eveningHeadline {
                Text(evening)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.nobsInk)
                    .lineLimit(snapshot.responseLength.toplineLineLimit)
                    .minimumScaleFactor(0.85)
            } else {
                Text(snapshot.topline)
                    .font(.subheadline)
                .foregroundStyle(Color.nobsInk)
                    .lineLimit(snapshot.responseLength.toplineLineLimit)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
            footerRow(snapshot: snapshot, redacted: redacted, compact: true)
        }
        .padding(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(smallAccessibilityLabel(snapshot: snapshot, redacted: redacted))
    }

    private func mediumView(snapshot: BriefingSnapshot, redacted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                header(for: snapshot)
                Spacer(minLength: 0)
                if snapshot.isStale {
                    Text("Stale")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.nobsWarning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.nobsWarning.opacity(0.15), in: Capsule())
                }
            }
            Text(snapshot.topline)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.nobsInk)
                .lineLimit(snapshot.responseLength.toplineLineLimit)
                .minimumScaleFactor(0.85)

            if snapshot.showsEveningContext, let evening = snapshot.eveningHeadline {
                Text(evening)
                    .font(.caption)
                    .foregroundStyle(Color.nobsMuted)
                    .lineLimit(2)
            }

            if redacted {
                if snapshot.priorityCount > 0 {
                    Text("\(snapshot.priorityCount) priorit\(snapshot.priorityCount == 1 ? "y" : "ies")")
                        .font(.caption)
                        .foregroundStyle(Color.nobsMuted)
                }
            } else if !snapshot.priorities.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(snapshot.priorities.prefix(snapshot.responseLength.maxWidgetPriorities).enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundStyle(Color.nobsAccent)
                            Text(item)
                                .font(.caption)
                                .foregroundStyle(Color.nobsInk)
                                .lineLimit(1)
                        }
                    }
                    if snapshot.priorityCount > snapshot.responseLength.maxWidgetPriorities {
                        Text("+\(snapshot.priorityCount - snapshot.responseLength.maxWidgetPriorities) more in app")
                            .font(.caption2)
                            .foregroundStyle(Color.nobsMuted)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text(relativeUpdated(snapshot.generatedAt))
                    .font(.caption2)
                    .foregroundStyle(Color.nobsMuted)
                Spacer()
                Text("Open plan")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.nobsForest)
                routePill(snapshot.route)
            }
            footerRow(snapshot: snapshot, redacted: redacted, compact: false)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mediumAccessibilityLabel(snapshot: snapshot, redacted: redacted))
    }

    private func lockScreenView(snapshot: BriefingSnapshot, redacted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.showsEveningContext ? "NOBS · Evening" : "NOBS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.nobsAccent)
            Text(snapshot.eveningHeadline ?? snapshot.topline)
                .font(.caption)
                .lineLimit(2)
            if snapshot.hasConflict {
                Text(snapshot.conflictLabel(redacted: true) ?? "Conflict")
                    .font(.caption2)
                    .foregroundStyle(Color.nobsWarning)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(for: nil)
            Text("Open NOBS to build today's plan.")
                .font(.subheadline)
                .foregroundStyle(Color.nobsMuted)
                .lineLimit(3)
            Text("Add this widget after your first briefing.")
                .font(.caption2)
                .foregroundStyle(Color.nobsMuted)
            Spacer(minLength: 0)
        }
        .padding(12)
        .accessibilityLabel("NOBS plan not ready. Open the app to build today's plan.")
    }

    @ViewBuilder
    private func header(for snapshot: BriefingSnapshot?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: snapshot?.showsEveningContext == true ? "moon.stars.fill" : "leaf.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.nobsAccent)
            Text(snapshot?.showsEveningContext == true ? "NOBS · Evening" : "NOBS")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.nobsForest)
            Spacer()
        }
    }

    @ViewBuilder
    private func footerRow(snapshot: BriefingSnapshot, redacted: Bool, compact: Bool) -> some View {
        HStack(spacing: 8) {
            if snapshot.hasConflict {
                Label(snapshot.conflictLabel(redacted: redacted) ?? "Conflict", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.nobsWarning)
                    .lineLimit(1)
            }
            if !compact {
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                routePill(snapshot.route)
            }
        }
    }

    private func routePill(_ route: String) -> some View {
        Text(route)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.nobsAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.nobsSagePale, in: Capsule())
            .accessibilityLabel("Processed on \(route)")
    }

    private func relativeUpdated(_ date: Date) -> String {
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return "Updated \(relative.localizedString(for: date, relativeTo: .now))"
    }

    private func smallAccessibilityLabel(snapshot: BriefingSnapshot, redacted: Bool) -> String {
        var parts = [snapshot.showsEveningContext ? "Evening plan" : "Today's plan", snapshot.eveningHeadline ?? snapshot.topline]
        if snapshot.hasConflict {
            parts.append(snapshot.conflictLabel(redacted: redacted) ?? "Schedule conflict")
        }
        parts.append("Processed on \(snapshot.route)")
        return parts.joined(separator: ". ")
    }

    private func mediumAccessibilityLabel(snapshot: BriefingSnapshot, redacted: Bool) -> String {
        var parts = smallAccessibilityLabel(snapshot: snapshot, redacted: redacted)
        if !redacted, !snapshot.priorities.isEmpty {
            parts += ". Priorities: \(snapshot.priorities.joined(separator: ", "))"
        }
        return parts
    }
}

#Preview(as: .systemSmall) {
    BriefingWidget()
} timeline: {
    BriefingWidgetEntry(date: .now, snapshot: .sample)
    BriefingWidgetEntry(date: .now, snapshot: nil)
}

#Preview(as: .systemMedium) {
    BriefingWidget()
} timeline: {
    BriefingWidgetEntry(date: .now, snapshot: .sample)
}

#Preview(as: .accessoryRectangular) {
    BriefingWidget()
} timeline: {
    BriefingWidgetEntry(date: .now, snapshot: .sample)
}
