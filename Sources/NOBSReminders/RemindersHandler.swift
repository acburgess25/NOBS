/// NOBSReminders — Reminders via EventKit
///
/// Creates, queries, and completes reminders using Apple's EventKit framework.
/// Each reminder is tagged with `nobs-context:personal` or `nobs-context:work`
/// inside the notes field so work and personal reminders can be listed separately.
///
/// Required Info.plist key: NSRemindersUsageDescription

import Foundation

#if canImport(EventKit)
import EventKit
#endif

import NOBSCore

// MARK: - ReminderError

public enum ReminderError: Error, LocalizedError, Sendable {
    case accessDenied
    case notFound(String)
    case saveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied:           return "Reminders access was denied. Please allow access in Settings."
        case .notFound(let id):       return "Reminder '\(id)' not found"
        case .saveFailed(let reason): return "Failed to save reminder: \(reason)"
        }
    }
}

// MARK: - ReminderItem

/// A platform-agnostic representation of a reminder.
public struct ReminderItem: Sendable {
    public let id: String
    public let title: String
    public let dueDate: Date?
    public let isCompleted: Bool
    public let notes: String?
    public let dataContext: DataContext

    public init(
        id: String = UUID().uuidString,
        title: String,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        notes: String? = nil,
        dataContext: DataContext = .personal
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.notes = notes
        self.dataContext = dataContext
    }
}

// MARK: - RemindersHandler

/// Handles reminder-related intents using EventKit.
public actor RemindersHandler: IntentHandler {
#if canImport(EventKit)
    private let store = EKEventStore()
#endif

    public init() {}

    // MARK: IntentHandler

    public nonisolated func canHandle(_ intent: AssistantIntent) -> Bool {
        switch intent {
        case .createReminder, .listReminders, .completeReminder: return true
        default: return false
        }
    }

    public func handle(_ intent: AssistantIntent) async throws -> String {
        switch intent {
        case .createReminder(let title, let dueDate, let notes, let context):
            let item = ReminderItem(title: title, dueDate: dueDate, notes: notes, dataContext: context)
            try await create(item)
            return "Reminder '\(title)' created."
        case .listReminders(let context):
            let items = try await list(context: context)
            if items.isEmpty { return "No pending \(context.rawValue) reminders." }
            return items
                .map { "• \($0.title)" + ($0.dueDate.map { " (due \(Self.format($0)))" } ?? "") }
                .joined(separator: "\n")
        case .completeReminder(let id):
            try await complete(id: id)
            return "Reminder marked as completed."
        default:
            throw ReminderError.saveFailed("Unsupported intent")
        }
    }

    // MARK: - CRUD

    public func create(_ item: ReminderItem) async throws {
#if canImport(EventKit)
        try await requestAccess()
        let reminder = EKReminder(eventStore: store)
        reminder.title = item.title
        reminder.notes = [item.notes, "nobs-context:\(item.dataContext.rawValue)"]
            .compactMap { $0 }
            .joined(separator: "\n")
        if let due = item.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: due
            )
            reminder.addAlarm(EKAlarm(absoluteDate: due))
        }
        reminder.calendar = store.defaultCalendarForNewReminders()
        do {
            try store.save(reminder, commit: true)
        } catch {
            throw ReminderError.saveFailed(error.localizedDescription)
        }
#endif
    }

    public func list(context: DataContext) async throws -> [ReminderItem] {
#if canImport(EventKit)
        try await requestAccess()
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil
        )
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { ekReminders in
                let tag = "nobs-context:\(context.rawValue)"
                let items = (ekReminders ?? [])
                    .filter { $0.notes?.contains(tag) == true }
                    .map { r -> ReminderItem in
                        ReminderItem(
                            id: r.calendarItemIdentifier,
                            title: r.title ?? "",
                            dueDate: r.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                            isCompleted: r.isCompleted,
                            notes: r.notes,
                            dataContext: context
                        )
                    }
                continuation.resume(returning: items)
            }
        }
#else
        return []
#endif
    }

    public func complete(id: String) async throws {
#if canImport(EventKit)
        try await requestAccess()
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ReminderError.notFound(id)
        }
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
        } catch {
            throw ReminderError.saveFailed(error.localizedDescription)
        }
#endif
    }

    // MARK: - Private

#if canImport(EventKit)
    private func requestAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .authorized, .fullAccess:
            return
        case .notDetermined:
            let granted: Bool
            if #available(iOS 17, macOS 14, *) {
                granted = try await store.requestFullAccessToReminders()
            } else {
                granted = await withCheckedContinuation { cont in
                    store.requestAccess(to: .reminder) { ok, _ in cont.resume(returning: ok) }
                }
            }
            if !granted { throw ReminderError.accessDenied }
        default:
            throw ReminderError.accessDenied
        }
    }
#endif

    private static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
