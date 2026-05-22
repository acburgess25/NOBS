import AppIntents
import SwiftUI
import NOBSCore
import NOBSDatabase

struct NOBSShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateMemoryIntent(),
            phrases: [
                "Create a memory with \(.applicationName)",
                "Save a memory in \(.applicationName)",
                "Remember something with \(.applicationName)",
            ],
            shortTitle: "Save Memory",
            systemImageName: "brain.head.profile"
        )

        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task to \(.applicationName)",
                "Create a task in \(.applicationName)",
                "Remind me with \(.applicationName)",
            ],
            shortTitle: "Add Task",
            systemImageName: "checklist"
        )

        AppShortcut(
            intent: ListTasksIntent(),
            phrases: [
                "Show my tasks in \(.applicationName)",
                "What do I need to do in \(.applicationName)",
                "List my reminders in \(.applicationName)",
            ],
            shortTitle: "List Tasks",
            systemImageName: "list.bullet"
        )
    }
}

enum IntentContext: String, AppEnum {
    case personal
    case work

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Context"
    static var caseDisplayRepresentations: [IntentContext: DisplayRepresentation] = [
        .personal: "Personal",
        .work: "Work",
    ]
}

struct CreateMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Memory"
    static var description: IntentDescription = "Save a memory in your NOBS pantry"

    @Parameter(title: "Content", description: "What do you want to remember?")
    var content: String

    @Parameter(title: "Context")
    var context: IntentContext

    static var parameterSummary: some ParameterSummary {
        Summary("Remember \(\.$content)") {
            \.$context
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dc: DataContext = context == .personal ? .personal : .work
        let repo = MemoryRepository(context: dc)
        let encrypted = try CryptoHelper.encrypt(content)
        try repo.save(content: encrypted, tags: [dc.rawValue, "encrypted"])
        return .result(dialog: "I've locked that memory away in your \(context.rawValue) pantry.")
    }
}

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description: IntentDescription = "Create a new task"

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Due Date")
    var dueDate: Date?

    @Parameter(title: "Context")
    var context: IntentContext

    static var parameterSummary: some ParameterSummary {
        Summary("Add task \(\.$title)") {
            \.$context
            \.$dueDate
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dc: DataContext = context == .personal ? .personal : .work
        let repo = TaskRepository(context: dc)
        try repo.create(title: title, dueDate: dueDate)
        return .result(dialog: "Added '\(title)' to your \(dc.rawValue) tasks.")
    }
}

struct ListTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "List Tasks"
    static var description: IntentDescription = "Show your pending tasks"

    @Parameter(title: "Context")
    var context: IntentContext

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<[IntentTask]> {
        let dc: DataContext = context == .personal ? .personal : .work
        let repo = TaskRepository(context: dc)
        let tasks = try repo.fetchPending()
        let intentTasks = tasks.map { IntentTask(id: $0.id, title: $0.title, dueDate: $0.dueDate) }
        let count = intentTasks.count
        return .result(
            value: intentTasks,
            dialog: "You have \(count) pending \(dc.rawValue) task\(count == 1 ? "" : "s")."
        )
    }
}

struct IntentTask: AppEntity {
    var id: UUID
    var title: String
    var dueDate: Date?

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Task"
    static var defaultQuery = IntentTaskQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct IntentTaskQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [IntentTask] {
        return []
    }

    func suggestedEntities() async throws -> [IntentTask] {
        return []
    }
}
