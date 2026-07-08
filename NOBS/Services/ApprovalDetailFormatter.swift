import AnyCodable
import Foundation

enum ApprovalDetailFormatter {
    struct DetailLine: Identifiable {
        let id: String
        let label: String
        let value: String
        let systemImage: String?
    }

    struct Reversal {
        let label: String
        let detail: String
        let chatPrompt: String
    }

    static func humanToolTitle(_ toolName: String) -> String {
        switch toolName {
        case "control_home_device":
            return "Control device"
        case "control_secure_home_device":
            return "Control secure device"
        case "write_workspace_note":
            return "Save workspace note"
        case "read_project_file":
            return "Read project file"
        case "list_project_files":
            return "List project files"
        case "search_project_text":
            return "Search project"
        case "read_workspace_file":
            return "Read workspace file"
        case "list_workspace_files":
            return "List workspace files"
        default:
            return toolName
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    static func summaryLines(
        toolName: String,
        arguments: [String: AnyCodable]
    ) -> [DetailLine] {
        switch toolName {
        case "control_home_device", "control_secure_home_device":
            return homeDeviceLines(arguments)
        case "write_workspace_note":
            return workspaceNoteLines(arguments)
        case "read_project_file", "list_project_files", "search_project_text":
            return projectPathLines(toolName: toolName, arguments: arguments)
        case "read_workspace_file", "list_workspace_files":
            return workspacePathLines(toolName: toolName, arguments: arguments)
        case "propose_idea":
            return proposalLines(arguments)
        default:
            return genericLines(arguments)
        }
    }

    static func triggeredByLabel(_ triggeredBy: String?) -> String {
        switch triggeredBy?.lowercased() {
        case "scheduler":
            return "Scheduled on Tank"
        default:
            return "You asked in chat"
        }
    }

    static func triggeredBySymbol(_ triggeredBy: String?) -> String {
        switch triggeredBy?.lowercased() {
        case "scheduler":
            return "clock.badge.checkmark"
        default:
            return "person.fill"
        }
    }

    static func contextLabel(_ context: String?) -> String {
        switch context?.lowercased() {
        case "business":
            return "Business"
        case "shared":
            return "Shared"
        default:
            return "Personal"
        }
    }

    static func auditEventLabel(_ event: ApprovalAuditEvent) -> String {
        switch event.eventType {
        case "tool_executed":
            if let tool = event.detail["tool"]?.value as? String {
                return "Ran \(humanToolTitle(tool).lowercased())"
            }
            return "Tool executed"
        case "approval_executed":
            if let tool = event.detail["tool"]?.value as? String {
                return "Approved \(humanToolTitle(tool).lowercased())"
            }
            return "Approval executed"
        case "approval_denied":
            return "Approval denied"
        default:
            return event.eventType
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    static func reversal(for approval: PendingApproval) -> Reversal? {
        switch approval.toolName {
        case "control_home_device", "control_secure_home_device":
            return homeDeviceReversal(approval)
        case "write_workspace_note":
            return workspaceNoteReversal(approval)
        default:
            return nil
        }
    }

    private static func homeDeviceLines(_ arguments: [String: AnyCodable]) -> [DetailLine] {
        let entityID = stringValue(arguments["entity_id"])
        let service = stringValue(arguments["service"])
        var lines: [DetailLine] = []

        if !entityID.isEmpty {
            lines.append(
                DetailLine(
                    id: "device",
                    label: "Device",
                    value: friendlyEntityName(entityID),
                    systemImage: "house"
                )
            )
        }
        if !service.isEmpty {
            lines.append(
                DetailLine(
                    id: "action",
                    label: "Action",
                    value: friendlyServiceName(service),
                    systemImage: "bolt.fill"
                )
            )
        }
        if let serviceData = arguments["service_data"]?.value as? [String: Any] {
            let extras = serviceData
                .filter { $0.key != "entity_id" }
                .sorted { $0.key < $1.key }
                .map { "\(humanizeKey($0.key)): \(String(describing: $0.value))" }
            if !extras.isEmpty {
                lines.append(
                    DetailLine(
                        id: "options",
                        label: "Options",
                        value: extras.joined(separator: ", "),
                        systemImage: "slider.horizontal.3"
                    )
                )
            }
        }
        return lines
    }

    private static func workspaceNoteLines(_ arguments: [String: AnyCodable]) -> [DetailLine] {
        let title = stringValue(arguments["title"])
        let context = stringValue(arguments["context"])
        let content = stringValue(arguments["content"])
        var lines: [DetailLine] = []

        if !title.isEmpty {
            lines.append(
                DetailLine(
                    id: "title",
                    label: "Title",
                    value: title,
                    systemImage: "doc.text"
                )
            )
        }
        if !context.isEmpty {
            lines.append(
                DetailLine(
                    id: "context",
                    label: "Workspace",
                    value: contextLabel(context),
                    systemImage: "folder"
                )
            )
        }
        if !content.isEmpty {
            let preview = content.count > 120 ? "\(content.prefix(120))…" : content
            lines.append(
                DetailLine(
                    id: "content",
                    label: "Content",
                    value: preview,
                    systemImage: "text.alignleft"
                )
            )
        }
        return lines
    }

    private static func projectPathLines(
        toolName: String,
        arguments: [String: AnyCodable]
    ) -> [DetailLine] {
        var lines: [DetailLine] = []
        if let path = arguments["path"]?.displayString, !path.isEmpty {
            lines.append(
                DetailLine(
                    id: "path",
                    label: "File path",
                    value: friendlyPath(path),
                    systemImage: "folder"
                )
            )
        }
        if toolName == "search_project_text", let query = arguments["query"]?.displayString, !query.isEmpty {
            lines.append(
                DetailLine(
                    id: "query",
                    label: "Search",
                    value: query,
                    systemImage: "magnifyingglass"
                )
            )
        }
        return lines.isEmpty ? genericLines(arguments) : lines
    }

    private static func workspacePathLines(
        toolName: String,
        arguments: [String: AnyCodable]
    ) -> [DetailLine] {
        var lines: [DetailLine] = []
        if let context = arguments["context"]?.displayString, !context.isEmpty {
            lines.append(
                DetailLine(
                    id: "context",
                    label: "Workspace",
                    value: contextLabel(context),
                    systemImage: "folder"
                )
            )
        }
        if let path = arguments["path"]?.displayString, !path.isEmpty {
            lines.append(
                DetailLine(
                    id: "path",
                    label: "File path",
                    value: friendlyPath(path),
                    systemImage: "doc"
                )
            )
        }
        return lines.isEmpty ? genericLines(arguments) : lines
    }

    private static func proposalLines(_ arguments: [String: AnyCodable]) -> [DetailLine] {
        var lines: [DetailLine] = []
        if let title = arguments["title"]?.displayString, !title.isEmpty {
            lines.append(
                DetailLine(
                    id: "title",
                    label: "Idea",
                    value: title,
                    systemImage: "lightbulb"
                )
            )
        }
        if let type = arguments["proposal_type"]?.displayString, !type.isEmpty {
            lines.append(
                DetailLine(
                    id: "type",
                    label: "Type",
                    value: type.capitalized,
                    systemImage: "tag"
                )
            )
        }
        if let description = arguments["description"]?.displayString, !description.isEmpty {
            let preview = description.count > 120 ? "\(description.prefix(120))…" : description
            lines.append(
                DetailLine(
                    id: "description",
                    label: "Details",
                    value: preview,
                    systemImage: "text.alignleft"
                )
            )
        }
        return lines
    }

    private static func genericLines(_ arguments: [String: AnyCodable]) -> [DetailLine] {
        arguments.keys.sorted().map { key in
            DetailLine(
                id: key,
                label: humanizeKey(key),
                value: arguments[key]?.displayString ?? "",
                systemImage: nil
            )
        }
    }

    private static func homeDeviceReversal(_ approval: PendingApproval) -> Reversal? {
        let service = stringValue(approval.arguments["service"])
        let entityID = stringValue(approval.arguments["entity_id"])
        guard !service.isEmpty, !entityID.isEmpty,
              let reverseService = reverseHomeService(service) else {
            return nil
        }

        let device = friendlyEntityName(entityID)
        let undoAction = friendlyServiceName(reverseService)
        return Reversal(
            label: "Undo path available",
            detail: "After approval, undo by asking NOBS to \(undoAction.lowercased()) \(device).",
            chatPrompt: """
            Please reverse the approved home action for \(entityID) by using \
            \(approval.toolName) with service \(reverseService) and the same entity_id. \
            Queue it for my approval before changing anything.
            """
        )
    }

    private static func workspaceNoteReversal(_ approval: PendingApproval) -> Reversal? {
        let title = stringValue(approval.arguments["title"])
        let context = stringValue(approval.arguments["context"])
        guard !title.isEmpty, !context.isEmpty else { return nil }

        let slug = title
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let path = "\(context)/\(slug.isEmpty ? "note" : String(slug.prefix(80))).md"

        return Reversal(
            label: "Undo path available",
            detail: "After approval, you can remove the note at \(friendlyPath(path)).",
            chatPrompt: """
            Please delete the workspace note titled "\(title)" from the \(context) workspace \
            if it exists. Queue any state change for my approval before deleting anything.
            """
        )
    }

    private static func friendlyEntityName(_ entityID: String) -> String {
        let raw = entityID.split(separator: ".").last.map(String.init) ?? entityID
        return raw
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func friendlyServiceName(_ service: String) -> String {
        switch service {
        case "turn_on":
            return "Turn on"
        case "turn_off":
            return "Turn off"
        case "lock":
            return "Lock"
        case "unlock":
            return "Unlock"
        case "open_cover":
            return "Open"
        case "close_cover":
            return "Close"
        case "set_temperature":
            return "Set temperature"
        default:
            return service
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    private static func reverseHomeService(_ service: String) -> String? {
        switch service {
        case "turn_on":
            return "turn_off"
        case "turn_off":
            return "turn_on"
        case "lock":
            return "unlock"
        case "unlock":
            return "lock"
        case "open_cover":
            return "close_cover"
        case "close_cover":
            return "open_cover"
        default:
            return nil
        }
    }

    private static func friendlyPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return path }
        if trimmed.contains("/") {
            return trimmed
        }
        return trimmed
    }

    private static func humanizeKey(_ key: String) -> String {
        key
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func stringValue(_ value: AnyCodable?) -> String {
        value?.displayString.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
