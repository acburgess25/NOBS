/// AssistantIntent — Typed intents produced by the AI model.
///
/// Every action the assistant can take is represented as a case of this enum.
/// `NOBSAssistant` dispatches these to the appropriate module handler.

import Foundation

// MARK: - AssistantIntent

public enum AssistantIntent: Sendable {
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
