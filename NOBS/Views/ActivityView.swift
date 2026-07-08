import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var model: AppModel
    let onSelectReceipt: (PrivacyReceipt) -> Void
    @State private var researchTopic = ""
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
                                .background(Color.red, in: RoundedRectangle(cornerRadius: 8))
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
            Section("Research briefs") {
                researchContent
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
                                        item.route.rawValue,
                                        systemImage: item.route.symbol
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
        .scrollContentBackground(.hidden)
        .task {
            await model.loadSchedules()
            await model.loadResearchJobs()
        }
    }

    @ViewBuilder
    private var researchContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask Tank to research a topic while you're away. Results include cited sources; any external action still needs approval.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("Research topic…", text: $researchTopic)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let topic = researchTopic
                    researchTopic = ""
                    Task { await model.startResearch(topic: topic) }
                } label: {
                    if model.isSubmittingResearch {
                        ProgressView()
                    } else {
                        Text("Start")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .disabled(
                    model.isSubmittingResearch
                    || researchTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !model.tankAvailable
                )
            }
        }
        .padding(.vertical, 4)

        if model.isLoadingResearch && model.researchJobs.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading research jobs…")
                    .foregroundStyle(.secondary)
            }
        } else if model.researchFetchState == .unavailable && model.researchJobs.isEmpty {
            Text("Connect Tank to request research briefs.")
                .foregroundStyle(.secondary)
        } else if let message = model.researchFetchState.errorMessage, model.researchJobs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await model.loadResearchJobs() } }
                    .buttonStyle(.bordered)
                    .tint(accent)
            }
        } else if model.researchJobs.isEmpty {
            Text("No research jobs yet")
                .foregroundStyle(.secondary)
        } else {
            ForEach(model.researchJobs) { job in
                researchJobRow(job)
            }
        }
    }

    private func researchJobRow(_ job: ResearchJob) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(job.topic)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(job.statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(job.status == "completed" ? accent : .secondary)
            }
            if let summary = job.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            if !job.sources.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sources")
                        .font(.caption.weight(.semibold))
                    ForEach(job.sources.prefix(5)) { source in
                        if let url = URL(string: source.url) {
                            Link(destination: url) {
                                Label(source.title, systemImage: "link")
                                    .font(.caption)
                            }
                        } else {
                            Text(source.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if job.sources.count > 5 {
                        Text("+\(job.sources.count - 5) more sources")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(job.displayDate)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
