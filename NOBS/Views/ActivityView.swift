import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var model: AppModel
    let onSelectReceipt: (PrivacyReceipt) -> Void
    private let accent = Color.nobsAccent

    var body: some View {
        List {
            if model.pendingDecisionCount > 0 {
                Section {
                    Button {
                        model.section = .approvals
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.nobsDestructive, in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(model.pendingDecisionCount) item\(model.pendingDecisionCount == 1 ? "" : "s") need your attention")
                                    .font(.subheadline.weight(.semibold))
                                Text("Go to Approvals →")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("Sync schedules") {
                schedulesContent
            }
            Section("Sync now") {
                Button {
                    Task { await model.syncCalendarToTank() }
                } label: {
                    HStack {
                        Label("Sync calendar to Tank", systemImage: "calendar")
                        Spacer()
                        if model.isSyncingCalendar { ProgressView() }
                    }
                }
                .disabled(model.isSyncingCalendar || !model.tankAvailable)

                Button {
                    Task { await model.syncRemindersToTank() }
                } label: {
                    HStack {
                        Label("Sync reminders to Tank", systemImage: "checklist")
                        Spacer()
                        if model.isSyncingReminders { ProgressView() }
                    }
                }
                .disabled(model.isSyncingReminders || !model.tankAvailable)
            }
            Section("Recent sync actions") {
                if model.syncActivity.isEmpty {
                    Text("No sync actions yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.syncActivity) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Button {
                                    onSelectReceipt(item.receipt)
                                } label: {
                                    Label(
                                        item.route.displayLabel(showPCCBadge: model.showPCCBadge),
                                        systemImage: item.route.displaySystemImage(showPCCBadge: model.showPCCBadge)
                                    )
                                    .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(accent)
                            }
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.createdAt, format: .relative(presentation: .named))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            Section("Recent on this device") {
                if model.activity.isEmpty {
                    Text("No activity yet").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.activity.enumerated()), id: \.offset) { _, item in
                        Label(item, systemImage: "checkmark.circle")
                    }
                }
            }
        }
        .nobsListScreen()
        .task { await model.loadSchedules() }
    }

    @ViewBuilder
    private var schedulesContent: some View {
        if model.schedulesFetchState == .idle || (model.isLoadingSchedules && model.schedules.isEmpty) {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading schedules from Tank…")
                    .foregroundStyle(.secondary)
            }
        } else if model.schedulesFetchState == .unavailable {
            Text("Connect Tank to manage sync schedules.")
                .foregroundStyle(.secondary)
        } else if let message = model.schedulesFetchState.errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await model.loadSchedules() } }
                    .buttonStyle(.bordered)
                    .tint(accent)
            }
        } else if model.schedules.isEmpty {
            Text("No schedules yet")
                .foregroundStyle(.secondary)
        } else {
            ForEach(model.schedules) { schedule in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Daily \(schedule.timeOfDay)", systemImage: "clock")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(schedule.status.capitalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(schedule.status == "active" ? accent : .secondary)
                    }
                    HStack(spacing: 10) {
                        if schedule.status == "active" {
                            Button("Pause") { Task { await model.updateSchedule(schedule, status: "paused") } }
                                .buttonStyle(.bordered)
                        } else if schedule.status == "paused" {
                            Button("Resume") { Task { await model.updateSchedule(schedule, status: "active") } }
                                .buttonStyle(.bordered)
                        }
                        if schedule.status != "revoked" {
                            Button("Revoke", role: .destructive) {
                                Task { await model.updateSchedule(schedule, status: "revoked") }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
