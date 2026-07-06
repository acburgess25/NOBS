import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoundationModelResponse {
    let message: String
    let route: ProcessingRoute
    let receipt: PrivacyReceipt
}

actor FoundationModelService {
    func isAvailable() -> Bool {
        guard #available(iOS 26.0, *) else { return false }
        #if canImport(FoundationModels)
        return SystemLanguageModel.default.isAvailable
        #else
        return false
        #endif
    }

    func chat(entries: [ConversationEntry]) async throws -> FoundationModelResponse {
        guard #available(iOS 26.0, *) else { throw FoundationModelServiceError.unavailable }
        #if canImport(FoundationModels)
        guard SystemLanguageModel.default.isAvailable else {
            throw FoundationModelServiceError.unavailable
        }

        let session = LanguageModelSession(model: .default) {
            """
            You are NOBS, a calm and privacy-first daily assistant.
            Keep responses concise, honest about limitations, and focused on reducing mental load.
            Do not claim a feature has already run unless the conversation confirms it.
            """
        }
        let response = try await session.respond(to: chatPrompt(for: entries.suffix(20)))
        return FoundationModelResponse(
            message: response.content.trimmingCharacters(in: .whitespacesAndNewlines),
            route: .onDevice,
            receipt: .onDevice
        )
        #else
        throw FoundationModelServiceError.unavailable
        #endif
    }

    func generateBriefing(events: [DayEvent]) async throws -> DailyBriefing {
        guard #available(iOS 26.0, *) else { throw FoundationModelServiceError.unavailable }
        #if canImport(FoundationModels)
        guard SystemLanguageModel.default.isAvailable else {
            throw FoundationModelServiceError.unavailable
        }

        let session = LanguageModelSession(model: .default) {
            """
            You are NOBS, creating a structured morning briefing from visible calendar events.
            Use only the event titles, times, and context labels provided in the prompt.
            Never invent attendees, notes, or locations.
            Return exactly these labeled sections, each followed by one item per line:
            TOPLINE: (one sentence describing the day's overall load and mix)
            PRIORITIES:
            CONFLICTS:
            PLAN:
            QUESTION: (one clarifying question only if there is genuine ambiguity, otherwise leave empty)
            ACTIONS:
            """
        }
        let response = try await session.respond(to: briefingPrompt(for: events))
        let fields = parseBriefingFields(from: response.content)

        return DailyBriefing(
            date: dayFormatter.string(from: Date()),
            topline: fields.topline,
            priorities: fields.priorities,
            conflictsOrRisks: fields.conflictsOrRisks,
            recommendedPlan: fields.recommendedPlan,
            oneUsefulQuestion: fields.oneUsefulQuestion,
            suggestedNextActions: fields.suggestedNextActions,
            generatedAt: timestampFormatter.string(from: Date()),
            route: .onDevice,
            privacyReceipt: PrivacyReceipt(
                used: [
                    "visible calendar event titles",
                    "visible calendar event times",
                    "calendar context labels"
                ],
                processed: "On this iPhone using Apple Intelligence",
                shared: [],
                changed: []
            )
        )
        #else
        throw FoundationModelServiceError.unavailable
        #endif
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var eventTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private var timestampFormatter: ISO8601DateFormatter {
        ISO8601DateFormatter()
    }

    private func chatPrompt(for entries: ArraySlice<ConversationEntry>) -> String {
        let transcript = entries.map { entry in
            "\(entry.role == .user ? "User" : "NOBS"): \(entry.text)"
        }.joined(separator: "\n")

        return """
        Continue this conversation as NOBS.

        \(transcript)

        Reply with the next assistant message only.
        """
    }

    private func briefingPrompt(for events: [DayEvent]) -> String {
        let eventLines: String
        if events.isEmpty {
            eventLines = "No visible events remain today."
        } else {
            eventLines = events.map { event in
                let overlap = event.overlapsNext ? " (overlaps next event)" : ""
                return "\(eventTimeFormatter.string(from: event.start)) | \(briefingContext(for: event.calendarName)) | \(event.title)\(overlap)"
            }.joined(separator: "\n")
        }

        return """
        Date: \(dayFormatter.string(from: Date()))
        Visible events:
        \(eventLines)

        Write a realistic morning briefing with concise, helpful guidance.
        """
    }

    private func briefingContext(for calendarName: String) -> String {
        let name = calendarName.lowercased()
        if name.contains("work") || name.contains("business") { return "business" }
        if name.contains("family") || name.contains("shared") { return "shared" }
        return "personal"
    }

    private struct BriefingFields {
        var topline: String
        var priorities: [String]
        var conflictsOrRisks: [String]
        var recommendedPlan: [String]
        var oneUsefulQuestion: String?
        var suggestedNextActions: [String]
    }

    private func parseBriefingFields(from text: String) -> BriefingFields {
        enum Section { case topline, priorities, conflicts, plan, question, actions, none }
        var current: Section = .none
        var toplineLines: [String] = []
        var priorityLines: [String] = []
        var conflictLines: [String] = []
        var planLines: [String] = []
        var questionLines: [String] = []
        var actionLines: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let normalized = line.uppercased()
            if normalized.hasPrefix("TOPLINE:") {
                current = .topline
                let rest = String(line.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rest.isEmpty { toplineLines.append(rest) }
            } else if normalized.hasPrefix("PRIORITIES:") {
                current = .priorities
            } else if normalized.hasPrefix("CONFLICTS:") {
                current = .conflicts
            } else if normalized.hasPrefix("PLAN:") {
                current = .plan
            } else if normalized.hasPrefix("QUESTION:") {
                current = .question
                let rest = String(line.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rest.isEmpty { questionLines.append(rest) }
            } else if normalized.hasPrefix("ACTIONS:") {
                current = .actions
            } else {
                let cleaned = line
                    .replacingOccurrences(of: "•", with: "")
                    .replacingOccurrences(of: "- ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { continue }
                switch current {
                case .topline: toplineLines.append(cleaned)
                case .priorities: priorityLines.append(cleaned)
                case .conflicts: conflictLines.append(cleaned)
                case .plan: planLines.append(cleaned)
                case .question: questionLines.append(cleaned)
                case .actions: actionLines.append(cleaned)
                case .none: break
                }
            }
        }

        let topline = toplineLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let question = questionLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return BriefingFields(
            topline: topline.isEmpty ? "Your day is visible on this iPhone." : topline,
            priorities: priorityLines.isEmpty ? ["Review your calendar before your first commitment."] : Array(priorityLines.prefix(5)),
            conflictsOrRisks: conflictLines.isEmpty ? ["No major schedule risks detected."] : Array(conflictLines.prefix(8)),
            recommendedPlan: planLines.isEmpty ? ["Work through your highest-priority commitment first."] : Array(planLines.prefix(10)),
            oneUsefulQuestion: question.isEmpty ? nil : question,
            suggestedNextActions: Array(actionLines.prefix(6))
        )
    }

}

private enum FoundationModelServiceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Intelligence is not available on this iPhone right now."
        }
    }
}
