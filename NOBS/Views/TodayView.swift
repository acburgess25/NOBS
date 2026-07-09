import EventKit
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    let onShowReceipt: (PrivacyReceipt) -> Void
    private let accent = Color.nobsAccent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("A realistic day, not another list.")
                    .nobsSerifTitle(30)
                briefingCard
                switch model.calendarStatus {
                case .fullAccess, .authorized:
                    if model.isLoadingCalendar {
                        ProgressView("Reading today's events on this iPhone…")
                    } else if model.events.isEmpty {
                        ContentUnavailableView("Your day is clear", systemImage: "calendar", description: Text("No calendar events remain today."))
                    } else {
                        ForEach(model.events) { event in eventRow(event) }
                        Button("Refresh calendar") { Task { await model.loadToday() } }
                            .buttonStyle(.bordered)
                            .tint(accent)
                    }
                case .denied, .restricted:
                    ContentUnavailableView("Calendar access is off", systemImage: "calendar.badge.exclamationmark", description: Text("Enable Calendar access in Settings to build a real day plan."))
                default:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connect your calendar when its value is clear—not during a wall of setup switches.")
                            .foregroundStyle(.secondary)
                        Button("Allow Calendar access") { Task { await model.requestCalendarAccess() } }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                    }
                    .nobsSectionCard()
                }
                reminderSection
                if model.shouldShowEveningWrapUp {
                    eveningWrapUpCard
                }
            }
            .padding(20)
        }
    }

    private var briefingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Morning briefing", systemImage: "sunrise")
                    .font(.headline)
                Spacer()
                if model.briefing != nil {
                    Button {
                        Task { await model.generateBriefing() }
                    } label: {
                        if model.isGeneratingBriefing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.isGeneratingBriefing)
                    .accessibilityLabel("Refresh morning briefing")
                }
            }
            if let briefing = model.briefing {
                if let generatedLabel = briefingGeneratedLabel(briefing.generatedAt) {
                    Text(generatedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Briefing generated \(generatedLabel)")
                }
                briefingParagraph("Topline", text: briefing.topline)
                briefingListSection("Priorities", items: briefing.priorities)
                briefingListSection("Conflicts or risks", items: briefing.conflictsOrRisks)
                briefingListSection("Recommended plan", items: briefing.recommendedPlan)
                if let question = briefing.oneUsefulQuestion, !question.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        briefingParagraph("One useful question", text: question)
                        if model.highlightClarifyingQuestion {
                            Text("Notifications are off — answer here when you have a moment.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accent)
                                .padding(10)
                                .background(Color.nobsWarning.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }
                        if model.clarifyingConflict != nil {
                            Button("Resolve overlap") {
                                model.showConflictSheet = true
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                }
                briefingListSection("Suggested next actions", items: briefing.suggestedNextActions)
                HStack(spacing: 10) {
                    Label(briefing.route.rawValue, systemImage: briefing.route == .tank ? "server.rack" : "iphone")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .accessibilityLabel("Processed on \(briefing.route.rawValue)")
                    Spacer()
                    Button("Privacy receipt") { onShowReceipt(briefing.privacyReceipt) }
                        .font(.caption.weight(.semibold))
                }
            } else {
                Text("Build on-device first from visible events and reminders, then refine on Tank when connected. No silent changes are made.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await model.generateBriefing() }
                } label: {
                    if model.isGeneratingBriefing {
                        ProgressView()
                    } else {
                        Text("Create from \(model.events.count) event\(model.events.count == 1 ? "" : "s") and \(model.reminders.count) reminder\(model.reminders.count == 1 ? "" : "s")")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(model.isGeneratingBriefing)
            }
        }
        .nobsSectionCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Morning briefing")
    }

    private var listItemLimit: Int {
        model.profile.accessibilityPreferences.responseLength.maxListItems
    }

    private func briefingGeneratedLabel(_ isoString: String) -> String? {
        guard let date = ISO8601DateFormatter().date(from: isoString) else { return nil }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        return "Updated \(relative.localizedString(for: date, relativeTo: .now))"
    }

    private var eveningWrapUpCard: some View {
        let wrapUp = model.generateEveningWrapUp()
        return VStack(alignment: .leading, spacing: 12) {
            Label("Evening wrap-up", systemImage: "moon.stars")
                .font(.headline)
            Text(wrapUp.headline)
                .font(.subheadline.weight(.medium))
            if !wrapUp.completedItems.isEmpty {
                eveningListSection("What you moved forward", items: wrapUp.completedItems)
            }
            if !wrapUp.stillOpen.isEmpty {
                eveningListSection("Can wait or carry forward", items: wrapUp.stillOpen)
            }
            Text(wrapUp.gentleClose)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .nobsSectionCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Evening wrap-up")
    }

    @ViewBuilder
    private func eveningListSection(_ title: String, items: [String]) -> some View {
        let visible = Array(items.prefix(listItemLimit))
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(accent)
            ForEach(Array(visible.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•").foregroundStyle(accent)
                    Text(item).font(.subheadline)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reminders", systemImage: "checklist")
                .font(.headline)
            if model.isLoadingReminders {
                ProgressView("Loading reminder context…")
            } else if model.hasReminderReadAccess {
                if model.reminders.isEmpty {
                    Text("No due reminders for today.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.reminders) { reminder in reminderRow(reminder) }
                    Button("Refresh reminders") { Task { await model.loadReminders() } }
                        .buttonStyle(.bordered)
                        .tint(accent)
                }
            } else {
                Text("Add reminders for better prep and conflict suggestions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Allow Reminders access") { Task { await model.requestReminderAccess() } }
                    .buttonStyle(.bordered)
                    .tint(accent)
            }
        }
        .nobsSectionCard()
    }

    private func briefingParagraph(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(accent)
            Text(text)
                .font(.subheadline)
                .lineLimit(model.profile.accessibilityPreferences.responseLength == .brief ? 3 : nil)
        }
    }

    @ViewBuilder
    private func briefingListSection(_ title: String, items: [String]) -> some View {
        let visible = Array(items.prefix(listItemLimit))
        if !visible.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption.weight(.bold)).foregroundStyle(accent)
                ForEach(Array(visible.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(accent)
                        Text(item).font(.subheadline)
                    }
                }
                if items.count > visible.count {
                    Text("\(items.count - visible.count) more in chat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title): \(visible.joined(separator: ", "))")
        }
    }

    private func eventRow(_ event: DayEvent) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(event.start, format: .dateTime.hour().minute())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(event.overlapsNext ? Color.nobsWarning : accent)
                .frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.title).font(.headline)
                    if event.overlapsNext { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.nobsWarning) }
                }
                Text(event.calendarName).font(.caption).foregroundStyle(.secondary)
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "location").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func reminderRow(_ reminder: DayReminder) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if let due = reminder.due {
                Text(due, format: .dateTime.hour().minute())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 76, alignment: .leading)
            } else {
                Text("Anytime")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 76, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title).font(.headline)
                Text(reminder.calendarName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
