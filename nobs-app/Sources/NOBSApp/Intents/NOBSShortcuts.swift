import AppIntents
import SwiftUI
import NOBSCore
import NOBSDatabase

// NOBSShortcuts intents — available in the Shortcuts app.
// Siri phrase registration is handled exclusively by NOBSShortcutsProvider (in NOBSIntents)
// to avoid duplicate AppShortcutsProvider conformances, which crash at runtime.
enum NOBSShortcuts {}

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

// MARK: - Focus Filter

/// When the user activates a Focus that includes a NOBS filter, iOS calls perform()
/// which flips the personal/work context switch stored in UserDefaults.
struct NOBSFocusFilterIntent: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Set NOBS Context"
    static var description = IntentDescription(
        "Switch NOBS between Personal and Work mode automatically when a Focus is active."
    )

    @Parameter(title: "Context", default: IntentContext.personal)
    var context: IntentContext

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "NOBS: \(context == .personal ? "Personal" : "Work") Mode")
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(context == .personal, forKey: "personal_mode_enabled")
        return .result()
    }
}
