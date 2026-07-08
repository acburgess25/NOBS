import SwiftUI

struct MemoryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingMemory: TankMemory?
    @State private var editContent = ""
    @State private var editCategory = "preference"

    private let accent = Color.nobsAccent
    private let categories = ["preference", "schedule", "relationship", "habit", "priority", "other"]

    var body: some View {
        List {
            if !model.tankAvailable {
                Section {
                    Text("Memories are stored on Tank. Reconnect in Privacy to view or edit what NOBS has learned.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if model.isLoadingMemories {
                Section {
                    HStack {
                        ProgressView().tint(accent)
                        Text("Loading memories…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if model.memories.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No memories yet")
                            .font(.headline)
                        Text("Say \"Remember that…\" in chat, or let NOBS infer useful facts from conversation. Everything appears here with its source and category.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section("What NOBS knows") {
                    ForEach(model.memories) { memory in
                        memoryRow(memory)
                    }
                }
            }
        }
        .refreshable { await model.loadMemories() }
        .task { await model.loadMemories() }
        .sheet(item: $editingMemory) { memory in
            correctionSheet(for: memory)
        }
    }

    private func memoryRow(_ memory: TankMemory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(memory.content)
                .font(.body)
            HStack(spacing: 10) {
                Label(memory.categoryTitle, systemImage: "tag")
                Label(memory.sourceTitle, systemImage: "arrow.down.left.and.arrow.up.right")
                Text(memory.displayDate)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack {
                Button("Correct") {
                    editingMemory = memory
                    editContent = memory.content
                    editCategory = memory.category
                }
                .font(.caption.weight(.semibold))
                Spacer()
                Button("Delete", role: .destructive) {
                    Task { await model.deleteMemory(memory) }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
    }

    private func correctionSheet(for memory: TankMemory) -> some View {
        NavigationStack {
            Form {
                Section("Memory") {
                    TextField("What should NOBS remember?", text: $editContent, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Category") {
                    Picker("Category", selection: $editCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category.capitalized).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Correct memory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingMemory = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let content = editContent.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !content.isEmpty else { return }
                        Task {
                            await model.updateMemory(memory, content: content, category: editCategory)
                            editingMemory = nil
                        }
                    }
                    .disabled(editContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
