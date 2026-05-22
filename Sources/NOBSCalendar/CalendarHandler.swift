/// NOBSCalendar — Calendar events via EventKit
///
/// Creates, lists, and deletes calendar events.
/// Required Info.plist key: NSCalendarsFullAccessUsageDescription

import Foundation

#if canImport(EventKit)
import EventKit
#endif

import NOBSCore

// MARK: - CalendarError

public enum CalendarError: Error, LocalizedError, Sendable {
    case accessDenied
    case saveFailed(String)
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied:           return "Calendar access denied. Allow access in Settings."
        case .saveFailed(let reason): return "Failed to save event: \(reason)"
        case .notFound(let id):       return "Event '\(id)' not found"
        }
    }
}

// MARK: - CalendarEvent

public struct CalendarEvent: Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let notes: String?

    public init(id: String = UUID().uuidString, title: String, startDate: Date,
                endDate: Date, location: String? = nil, notes: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
    }
}

// MARK: - CalendarHandler

public actor CalendarHandler: IntentHandler {

#if canImport(EventKit)
    private let store = EKEventStore()
#endif

    public init() {}

    // MARK: IntentHandler

    public nonisolated func canHandle(_ intent: AssistantIntent) -> Bool {
        switch intent {
        case .createEvent, .listEvents, .deleteEvent: return true
        default: return false
        }
    }

    public func handle(_ intent: AssistantIntent) async throws -> String {
        switch intent {
        case .createEvent(let title, let start, let end, let notes, let location):
            let item = CalendarEvent(title: title, startDate: start, endDate: end,
                                     location: location, notes: notes)
            try await create(item)
            let fmt = Self.formatDate(start)
            return "Scheduled '\(title)' for \(fmt)."

        case .listEvents(let from, let to):
            let events = try await list(from: from, to: to)
            guard !events.isEmpty else {
                return "Nothing on your calendar for that period."
            }
            return events.map { e in
                "• \(e.title) — \(Self.formatDate(e.startDate))"
                + (e.location.map { " @ \($0)" } ?? "")
            }.joined(separator: "\n")

        case .deleteEvent(let id):
            try await delete(id: id)
            return "Event removed from your calendar."

        default:
            throw CalendarError.saveFailed("Unsupported intent")
        }
    }

    // MARK: - CRUD

    public func create(_ event: CalendarEvent) async throws {
#if canImport(EventKit)
        try await requestAccess()
        let ek = EKEvent(eventStore: store)
        ek.title = event.title
        ek.startDate = event.startDate
        ek.endDate = event.endDate
        ek.notes = event.notes
        ek.location = event.location
        ek.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(ek, span: .thisEvent, commit: true)
        } catch {
            throw CalendarError.saveFailed(error.localizedDescription)
        }
#endif
    }

    public func list(from: Date, to: Date) async throws -> [CalendarEvent] {
#if canImport(EventKit)
        try await requestAccess()
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        return store.events(matching: predicate).map { ek in
            CalendarEvent(
                id: ek.eventIdentifier ?? UUID().uuidString,
                title: ek.title ?? "(No title)",
                startDate: ek.startDate,
                endDate: ek.endDate,
                location: ek.location,
                notes: ek.notes
            )
        }
#else
        return []
#endif
    }

    public func delete(id: String) async throws {
#if canImport(EventKit)
        try await requestAccess()
        guard let ek = store.event(withIdentifier: id) else {
            throw CalendarError.notFound(id)
        }
        do {
            try store.remove(ek, span: .thisEvent, commit: true)
        } catch {
            throw CalendarError.saveFailed(error.localizedDescription)
        }
#endif
    }

    // MARK: - Private

#if canImport(EventKit)
    private func requestAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized: return
        case .notDetermined:
            let granted: Bool
            if #available(iOS 17, macOS 14, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = await withCheckedContinuation { cont in
                    store.requestAccess(to: .event) { ok, _ in cont.resume(returning: ok) }
                }
            }
            if !granted { throw CalendarError.accessDenied }
        default:
            throw CalendarError.accessDenied
        }
    }
#endif

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
