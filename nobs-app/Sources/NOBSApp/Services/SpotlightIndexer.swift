import CoreSpotlight
import Foundation

final class SpotlightIndexer {
    static let shared = SpotlightIndexer()
    private init() {}

    private let domain = "com.nobsdash.nobs"

    func indexMemory(id: UUID, content: String, date: Date) {
        // Memory content stays encrypted — only expose the date and a fixed label so
        // Spotlight can find the NOBS entry without indexing the plaintext.
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = "NOBS Memory"
        attrs.contentDescription = "Encrypted private memory"
        attrs.contentCreationDate = date
        attrs.keywords = ["memory", "nobs"]
        commit(id: "memory-\(id.uuidString)", attrs: attrs)
    }

    func indexTask(id: UUID, title: String, dueDate: Date?) {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = title
        attrs.contentDescription = "Task"
        attrs.contentCreationDate = dueDate
        attrs.keywords = ["task", "nobs", "todo"]
        commit(id: "task-\(id.uuidString)", attrs: attrs)
    }

    func remove(id: String) {
        CSSearchableIndex.default()
            .deleteSearchableItems(withIdentifiers: [id]) { _ in }
    }

    private func commit(id: String, attrs: CSSearchableItemAttributeSet) {
        let item = CSSearchableItem(uniqueIdentifier: id, domainIdentifier: domain, attributeSet: attrs)
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error { print("NOBS Spotlight index error: \(error)") }
        }
    }
}
