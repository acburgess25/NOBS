import Foundation

struct QueuedChatMessage: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let text: String
    let queuedAt: Date

    init(id: UUID = UUID(), text: String, queuedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.queuedAt = queuedAt
    }
}

struct OfflineMessageQueue: Sendable {
    static let filename = AppGroupStore.offlineChatQueueFile

    func load() -> [QueuedChatMessage] {
        (try? AppGroupStore.readJSON([QueuedChatMessage].self, from: Self.filename)) ?? []
    }

    func save(_ messages: [QueuedChatMessage]) throws {
        try AppGroupStore.writeJSON(messages, to: Self.filename)
    }

    func enqueue(_ message: QueuedChatMessage) throws {
        var queue = load()
        queue.append(message)
        try save(queue)
    }

    func remove(id: UUID) throws {
        var queue = load()
        queue.removeAll { $0.id == id }
        try save(queue)
    }

    func clear() throws {
        try save([])
    }
}
