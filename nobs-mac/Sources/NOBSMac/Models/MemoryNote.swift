import Foundation

struct MemoryNote: Identifiable, Hashable {
    let id: UUID
    let title: String
    let relativePath: String
    let body: String
    let modifiedAt: Date

    var preview: String {
        body
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(5)
            .joined(separator: "\n")
    }
}

struct SystemSignal: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String
    let symbolName: String
    let tint: NOBSTint
}

enum NOBSTint: String, CaseIterable, Hashable {
    case amber
    case sage
    case blue
    case rose
    case graphite
}
