import WidgetKit
import SwiftUI
import AppIntents
import NOBSCore
import NOBSDatabase

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
        // Parse the String back to a UUID safely
        guard let uuid = UUID(uuidString: taskId) else {
            return .result()
        }
        
        // Access shared App Group Core Data database
        try NOBSDatabase.shared.setup(storageMode: .localOnly)
        let repo = TaskRepository(context: .personal)
        try repo.complete(id: uuid)
        
        // Return success. WidgetKit will automatically reload the widget timeline!
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
        
        // Refresh widget every 15 minutes to preserve battery while remaining fresh
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchStats() -> (tasks: Int, memories: Int, pending: [TaskInfo]) {
        do {
            // Setup shared or local Core Data stack
            try NOBSDatabase.shared.setup(storageMode: .localOnly)
            
            let taskRepo = TaskRepository(context: .personal)
            let memoryRepo = MemoryRepository(context: .personal)
            
            let allPending = try taskRepo.fetchPending()
            let tasksCount = allPending.count
            let memoriesCount = try memoryRepo.fetchAll().count
            
            // Map top 2 tasks to fit beautifully in the systemSmall widget size
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

// MARK: - Widget Entry View
struct NOBSWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title Bar with elegant memory badge
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
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

            // Body Content
            if entry.taskCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.pendingTasks, id: \.id) { task in
                        HStack(spacing: 8) {
                            Button(intent: CompleteTaskWidgetIntent(taskId: task.id)) {
                                Image(systemName: "circle")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.blue)
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
                        .foregroundStyle(.green)
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
}

// MARK: - Widget Configuration
struct NOBSWidget: Widget {
    let kind: String = "com.nobs.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NOBSWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NOBS Overview")
        .description("See your pending tasks and memories at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

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
    }
}
