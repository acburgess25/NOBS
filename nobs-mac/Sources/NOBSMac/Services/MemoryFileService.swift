import Foundation

struct MemoryFileService {
    private let fileManager = FileManager.default

    var memoryRoot: URL {
        URL(filePath: NSHomeDirectory())
            .appending(path: "Library/Mobile Documents/com~apple~CloudDocs/AI-Memory")
    }

    func loadNotes() -> [MemoryNote] {
        let roots = [
            memoryRoot.appending(path: "distilled"),
            memoryRoot.appending(path: "inbox"),
            memoryRoot
        ]

        let files = roots.flatMap { root -> [URL] in
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            return enumerator.compactMap { item in
                guard let url = item as? URL else { return nil }
                return url.pathExtension.lowercased() == "md" ? url : nil
            }
        }

        var seen = Set<URL>()

        return files.compactMap { url in
            guard seen.insert(url).inserted else { return nil }
            guard let body = try? String(contentsOf: url, encoding: .utf8) else { return nil }

            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let title = titleFromBody(body) ?? url.deletingPathExtension().lastPathComponent

            return MemoryNote(
                id: UUID(),
                title: title,
                relativePath: relativePath(for: url),
                body: body,
                modifiedAt: values?.contentModificationDate ?? .distantPast
            )
        }
        .sorted { lhs, rhs in
            lhs.modifiedAt > rhs.modifiedAt
        }
    }

    private func titleFromBody(_ body: String) -> String? {
        body
            .split(separator: "\n")
            .first { $0.hasPrefix("# ") }
            .map { String($0.dropFirst(2)) }
    }

    private func relativePath(for url: URL) -> String {
        let root = memoryRoot.path()
        let path = url.path()

        guard path.hasPrefix(root) else {
            return url.lastPathComponent
        }

        return String(path.dropFirst(root.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
