import WidgetKit
import SwiftUI
import AppIntents
import NOBSCore
import NOBSDatabase

#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Local theme shim
// NOBSTheme lives in the main app target; the widget accesses the same named assets directly.
private extension Color {
    static let nobsAccent = Color("NBAccent")   // #D97706 amber
    static let nobsGreen  = Color("NBGreen")    // #65A36E sage
}

private struct NOBSWidgetMark: View {
    var size: CGFloat

    var body: some View {
        Image("NOBSBrandMark")
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

// MARK: - Task Data Model
struct TaskInfo: Hashable, Codable, Sendable {
    let id: String // Stored as a UUID String to conform to AppIntents parameter types
    let title: String
    let dueDate: Date?
}

// MARK: - Interactive Widget Intent
struct CompleteTaskWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task from Widget"
    
    @Parameter(title: "Task ID")
    var taskId: String // UUID represented as String to satisfy _IntentValue conformance

    init() {}
    
    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskId) else {
            return .result()
        }
        try NOBSDatabase.shared.setup(storageMode: .localOnly)
        let repo = TaskRepository(context: .personal)
        try repo.complete(id: uuid)
        return .result()
    }
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), taskCount: 0, memoryCount: 0, pendingTasks: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let stats = fetchStats()
        completion(SimpleEntry(date: Date(), taskCount: stats.tasks, memoryCount: stats.memories, pendingTasks: stats.pending))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let stats = fetchStats()
        let entry = SimpleEntry(date: Date(), taskCount: stats.tasks, memoryCount: stats.memories, pendingTasks: stats.pending)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchStats() -> (tasks: Int, memories: Int, pending: [TaskInfo]) {
        do {
            try NOBSDatabase.shared.setup(storageMode: .localOnly)
            let taskRepo = TaskRepository(context: .personal)
            let memoryRepo = MemoryRepository(context: .personal)
            let allPending = try taskRepo.fetchPending()
            let tasksCount = allPending.count
            let memoriesCount = try memoryRepo.fetchAll().count
            let pendingTasks = allPending.prefix(2).map { 
                TaskInfo(id: $0.id.uuidString, title: $0.title, dueDate: $0.dueDate)
            }
            return (tasksCount, memoriesCount, pendingTasks)
        } catch {
            return (0, 0, [])
        }
    }
}

// MARK: - Timeline Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let taskCount: Int
    let memoryCount: Int
    let pendingTasks: [TaskInfo]
}

// MARK: - System Widget Entry View (small)
struct NOBSWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            systemSmallView
        }
    }

    // MARK: System small
    private var systemSmallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                NOBSWidgetMark(size: 18)
                Text("NOBS")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "brain")
                        .font(.system(size: 10))
                    Text("\(entry.memoryCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            if entry.taskCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.pendingTasks, id: \.id) { task in
                        HStack(spacing: 8) {
                            Button(intent: CompleteTaskWidgetIntent(taskId: task.id)) {
                                Image(systemName: "circle")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.nobsAccent)
                            }
                            .buttonStyle(.plain)
                            
                            Text(task.title)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                    
                    if entry.taskCount > 2 {
                        Text("+ \(entry.taskCount - 2) more task\(entry.taskCount - 2 == 1 ? "" : "s")")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 23)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.nobsGreen)
                    Text("All Caught Up")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("0 tasks remaining")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Lock screen circular — task count badge
    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: entry.taskCount == 0 ? "checkmark" : "checklist")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(entry.taskCount == 0 ? Color.nobsGreen : Color.nobsAccent)
                Text("\(entry.taskCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    // MARK: Lock screen rectangular — next task
    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                NOBSWidgetMark(size: 13)
                Text("NOBS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.nobsAccent)
            }
            if let task = entry.pendingTasks.first {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            } else {
                Text("All tasks complete")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - System Small Widget
struct NOBSWidget: Widget {
    let kind: String = "com.nobsdash.nobs.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NOBSWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NOBS Overview")
        .description("See your pending tasks and memories at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Lock Screen / StandBy Widget
struct NOBSLockWidget: Widget {
    let kind: String = "com.nobsdash.nobs.lockwidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NOBSWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NOBS Tasks")
        .description("Quick glance at pending tasks on your Lock Screen or StandBy.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Live Activity Widget

#if canImport(ActivityKit)
struct NOBSLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NOBSActivityAttributes.self) { context in
            // Lock screen / Notification Center banner
            HStack(spacing: 12) {
                if context.state.phase == "done" {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.nobsGreen)
                } else {
                    NOBSWidgetMark(size: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.userName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(context.state.message)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                Spacer()
                if context.state.phase == "thinking" {
                    ProgressView()
                        .tint(Color.nobsAccent)
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 8) {
                        NOBSWidgetMark(size: 18)
                        Text(context.state.message)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                NOBSWidgetMark(size: 16)
            } compactTrailing: {
                Group {
                    if context.state.phase == "thinking" {
                        ProgressView()
                            .tint(Color.nobsAccent)
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.nobsGreen)
                    }
                }
            } minimal: {
                NOBSWidgetMark(size: 12)
            }
        }
    }
}
#endif

// MARK: - Preview Provider
#Preview(as: .systemSmall) {
    NOBSWidget()
} timeline: {
    SimpleEntry(date: .now, taskCount: 3, memoryCount: 12, pendingTasks: [
        TaskInfo(id: UUID().uuidString, title: "Draft launch plan", dueDate: nil),
        TaskInfo(id: UUID().uuidString, title: "Buy groceries", dueDate: nil)
    ])
    SimpleEntry(date: .now, taskCount: 0, memoryCount: 8, pendingTasks: [])
}

// MARK: - Widget Bundle Entry Point
@main
struct NOBSWidgetBundle: WidgetBundle {
    var body: some Widget {
        NOBSWidget()
        NOBSLockWidget()
        #if canImport(ActivityKit)
        NOBSLiveActivityWidget()
        #endif
    }
}
