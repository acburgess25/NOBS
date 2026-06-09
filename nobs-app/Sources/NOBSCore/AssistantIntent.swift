/// AssistantIntent — Typed intents produced by the AI model.
///
/// Every action the assistant can take is represented as a case of this enum.
/// `NOBSAssistant` dispatches these to the appropriate module handler.

import Foundation

// MARK: - AssistantIntent

public enum AssistantIntent: Sendable, Decodable {
    // Phone
    case makeCall(phoneNumber: String, contactName: String?)
    case screenCall(phoneNumber: String)
    case endCall

    // Messaging
    case sendMessage(to: String, body: String)
    case readMessages(from: String?)

    // Smart home
    case controlDevice(deviceName: String, action: HomeAction)
    case runScene(sceneName: String)
    case queryDevice(deviceName: String)

    // Reminders
    case createReminder(title: String, dueDate: Date?, notes: String?, context: DataContext)
    case listReminders(context: DataContext)
    case completeReminder(id: String)

    // Calendar
    case createEvent(title: String, start: Date, end: Date, notes: String?, location: String?)
    case listEvents(from: Date, to: Date)
    case deleteEvent(id: String)

    // Web
    case browseWeb(query: String)

    // Knowledge
    case storeMemory(content: String, context: DataContext)
    case recallMemory(query: String, context: DataContext)

    // Meta
    case unknown(rawText: String)
}

// MARK: - Supporting types

/// Actions that can be applied to a smart-home device.
public enum HomeAction: String, Sendable, Codable {
    case turnOn
    case turnOff
    case setBrightness
    case lock
    case unlock
    case setTemperature
    case open
    case close
}

/// Distinguishes work data from personal data at the intent level.
public enum DataContext: String, Sendable, Codable, CaseIterable {
    case personal
    case work
}

// MARK: - Decodable Conformance

extension AssistantIntent {
    private enum CodingKeys: String, CodingKey {
        case intent, params
    }
    
    private struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let intentName = try container.decode(String.self, forKey: .intent)
        
        let params = try? container.nestedContainer(keyedBy: DynamicKey.self, forKey: .params)
        
        func decodeString(_ key: String) -> String? {
            guard let dynamicKey = DynamicKey(stringValue: key) else { return nil }
            return try? params?.decode(String.self, forKey: dynamicKey)
        }
        
        switch intentName {
        case "makeCall":
            self = .makeCall(
                phoneNumber: decodeString("phoneNumber") ?? "",
                contactName: decodeString("contactName")
            )
        case "screenCall":
            self = .screenCall(phoneNumber: decodeString("phoneNumber") ?? "")
        case "endCall":
            self = .endCall
        case "sendMessage":
            self = .sendMessage(
                to: decodeString("to") ?? "",
                body: decodeString("body") ?? ""
            )
        case "readMessages":
            self = .readMessages(from: decodeString("from"))
        case "controlDevice":
            let actionStr = decodeString("action") ?? ""
            let action = HomeAction(rawValue: actionStr) ?? .turnOn
            self = .controlDevice(
                deviceName: decodeString("deviceName") ?? "",
                action: action
            )
        case "runScene":
            self = .runScene(sceneName: decodeString("sceneName") ?? "")
        case "queryDevice":
            self = .queryDevice(deviceName: decodeString("deviceName") ?? "")
        case "createReminder":
            let ctxStr = decodeString("context") ?? ""
            let ctx = DataContext(rawValue: ctxStr) ?? .personal
            var dueDate: Date? = nil
            if let iso = decodeString("dueDate") {
                dueDate = ISO8601DateFormatter().date(from: iso)
            }
            self = .createReminder(
                title: decodeString("title") ?? "",
                dueDate: dueDate,
                notes: decodeString("notes"),
                context: ctx
            )
        case "listReminders":
            let ctxStr = decodeString("context") ?? ""
            let ctx = DataContext(rawValue: ctxStr) ?? .personal
            self = .listReminders(context: ctx)
        case "completeReminder":
            self = .completeReminder(id: decodeString("id") ?? "")
        case "createEvent":
            let iso = ISO8601DateFormatter()
            let now = Date()
            let start = decodeString("start").flatMap { iso.date(from: $0) } ?? now
            let end   = decodeString("end").flatMap   { iso.date(from: $0) } ?? start.addingTimeInterval(3600)
            self = .createEvent(
                title:    decodeString("title") ?? "",
                start:    start,
                end:      end,
                notes:    decodeString("notes"),
                location: decodeString("location")
            )
        case "listEvents":
            let iso = ISO8601DateFormatter()
            let from = decodeString("from").flatMap { iso.date(from: $0) } ?? Date()
            let to   = decodeString("to").flatMap   { iso.date(from: $0) } ?? from.addingTimeInterval(7 * 86400)
            self = .listEvents(from: from, to: to)
        case "deleteEvent":
            self = .deleteEvent(id: decodeString("id") ?? "")
        case "browseWeb":
            self = .browseWeb(query: decodeString("query") ?? "")
        case "storeMemory":
            let ctxStr = decodeString("context") ?? ""
            let ctx = DataContext(rawValue: ctxStr) ?? .personal
            self = .storeMemory(content: decodeString("content") ?? "", context: ctx)
        case "recallMemory":
            let ctxStr = decodeString("context") ?? ""
            let ctx = DataContext(rawValue: ctxStr) ?? .personal
            self = .recallMemory(query: decodeString("query") ?? "", context: ctx)
        default:
            self = .unknown(rawText: intentName)
        }
    }
    
    public static var availableIntents: String {
        return "makeCall, screenCall, endCall, sendMessage, readMessages, controlDevice, runScene, queryDevice, createReminder, listReminders, completeReminder, createEvent, listEvents, deleteEvent, browseWeb, storeMemory, recallMemory, unknown"
    }
}
