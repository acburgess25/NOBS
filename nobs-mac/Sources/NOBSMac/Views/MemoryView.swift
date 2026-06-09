import SwiftUI

struct MemoryView: View {
    @Environment(CommandCenterStore.self) private var store

    var body: some View {
        HSplitView {
            List(store.filteredNotes, selection: Bindable(store).selectedNote) { note in
                VStack(alignment: .leading, spacing: 5) {
                    Text(note.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(note.relativePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(note.preview)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
                .tag(note)
            }
            .frame(minWidth: 280, idealWidth: 340)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(
                        title: store.selectedNote?.title ?? "Memory",
                        subtitle: store.selectedNote?.relativePath ?? "Plain-text iCloud memory for every local agent."
                    )

                    GlassPanel {
                        Text(store.selectedNote?.body ?? "No memory file selected.")
                            .font(.system(.body, design: .rounded))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(28)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
