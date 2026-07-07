@preconcurrency import EventKit
import Foundation

@MainActor
final class CalendarService {
    private let store = EKEventStore()

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    func requestReminderAccess() async throws -> Bool {
        try await store.requestFullAccessToReminders()
    }

    func todayEvents() -> [DayEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let source = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        var result = source.map {
            DayEvent(
                id: $0.eventIdentifier ?? UUID().uuidString,
                title: $0.title.isEmpty ? "Untitled event" : $0.title,
                start: $0.startDate,
                end: $0.endDate,
                location: $0.location,
                calendarName: $0.calendar.title,
                context: Self.context(for: $0.calendar.title)
            )
        }
        for index in result.indices.dropLast() {
            result[index].overlapsNext = result[index].end > result[index + 1].start
        }
        return result
    }

    func todayReminders() async -> [DayReminder] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: start,
            ending: end,
            calendars: nil
        )
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let items = (reminders ?? []).map {
                    DayReminder(
                        id: $0.calendarItemIdentifier,
                        title: $0.title.isEmpty ? "Untitled reminder" : $0.title,
                        due: $0.dueDateComponents?.date,
                        calendarName: $0.calendar.title,
                        context: Self.context(for: $0.calendar.title)
                    )
                }
                .sorted { lhs, rhs in
                    (lhs.due ?? .distantFuture) < (rhs.due ?? .distantFuture)
                }
                continuation.resume(returning: items)
            }
        }
    }

    func syncEvents(daysAhead: Int) -> [DayEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: daysAhead, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                DayEvent(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title.isEmpty ? "Untitled event" : $0.title,
                    start: $0.startDate,
                    end: $0.endDate,
                    location: $0.location,
                    calendarName: $0.calendar.title,
                    context: Self.context(for: $0.calendar.title)
                )
            }
    }

    func openReminders(limit: Int) async -> [DayReminder] {
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        let reminders: [DayReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { fetched in
                let snapshot = (fetched ?? []).map { reminder in
                    DayReminder(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title?.isEmpty == false
                            ? (reminder.title ?? "Untitled reminder")
                            : "Untitled reminder",
                        due: reminder.dueDateComponents?.date,
                        calendarName: reminder.calendar.title,
                        context: Self.context(for: reminder.calendar.title)
                    )
                }
                continuation.resume(returning: snapshot)
            }
        }
        let sorted = reminders.sorted {
            ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture)
        }
        return Array(sorted.prefix(limit))
    }

    private static func context(for calendarName: String) -> BriefingContextBucket {
        let name = calendarName.lowercased()
        if name.contains("work") || name.contains("business") { return .business }
        if name.contains("family") || name.contains("shared") { return .shared }
        return .personal
    }
}
