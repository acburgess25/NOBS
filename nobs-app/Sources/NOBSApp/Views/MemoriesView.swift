import SwiftUI
import NOBSDatabase
import NOBSCore

struct MemoriesView: View {
    @State private var context: DataContext = NOBSDatabase.shared.isPersonalModeEnabled ? .personal : .work
    @State private var memories: [DecryptedMemory] = []
    @State private var newMemoryText = ""
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var repo: MemoryRepository {
        MemoryRepository(context: context)
    }

    var body: some View {
        NavigationStack {
            List {
                inputSection
                memoriesSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.nobsBg)
            .searchable(text: $searchText, prompt: "Search memories")
            .navigationTitle("Memories")
            .toolbar {
                if NOBSDatabase.shared.isPersonalModeEnabled {
                    contextPicker
                }
            }
            .task { loadMemories() }
            .refreshable { await refresh() }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") {}
            } message: { msg in
                Text(msg)
            }
            .overlay { emptyOverlay }
        }
    }

    @ViewBuilder
    private var inputSection: some View {
        Section {
            HStack(spacing: 8) {
                TextField("Write a memory...", text: $newMemoryText)
                    .textFieldStyle(.plain)
                    .font(NOBSFont.body())
                Button {
                    withAnimation(.spring(response: 0.3)) { saveMemory() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newMemoryText.trimmed.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.nobsAccent))
                        .padding(4)
                        .glassEffect(.regular.tint(Color.nobsAccent).interactive(), in: Circle())
                }
                .disabled(newMemoryText.trimmed.isEmpty)
                .sensoryFeedback(.success, trigger: memories.count)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.nobsCard)
    }

    private var memoriesSection: some View {
        Section {
            if isLoading && memories.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            }

            ForEach(filteredMemories, id: \.id) { memory in
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.content)
                        .font(NOBSFont.body())
                        .textSelection(.enabled)
                    HStack(spacing: 12) {
                        Label(memory.createdAt.formatted(date: .abbreviated, time: .shortened),
                              systemImage: "calendar")
                            .font(.caption2)
                            .foregroundStyle(Color.nobsTertiary)
                        NOBSTag(text: context.rawValue.capitalized, color: Color.nobsAccent)
                    }
                }
                .padding(.vertical, 2)
                .transition(.scale.combined(with: .opacity))
            }
        } header: {
            Text("All Memories").sectionOverline()
        }
        .listRowBackground(Color.nobsCard)
    }

    @ViewBuilder
    private var emptyOverlay: some View {
        if !isLoading && memories.isEmpty && searchText.isEmpty {
            ContentUnavailableView(
                "No Memories Yet",
                systemImage: "brain.head.profile",
                description: Text("Write your first memory above. They're encrypted and stored locally.")
            )
        } else if !isLoading && filteredMemories.isEmpty && !searchText.isEmpty {
            ContentUnavailableView.search
        }
    }

    private var contextPicker: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Context", selection: $context) {
                Text("Personal").tag(DataContext.personal)
                Text("Work").tag(DataContext.work)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .onChange(of: context) { _, _ in
                withAnimation { loadMemories() }
            }
        }
    }

    private var filteredMemories: [DecryptedMemory] {
        if searchText.isEmpty { return memories }
        return memories.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadMemories() {
        isLoading = true
        errorMessage = nil
        do {
            let raw = try repo.fetchAll()
            memories = raw.map { mo in
                let encrypted = mo.content
                let decrypted = (try? CryptoHelper.decrypt(encrypted)) ?? encrypted
                return DecryptedMemory(id: mo.id, content: decrypted, createdAt: mo.createdAt)
            }
            // Keep Spotlight index in sync with current memories
            for mem in memories {
                SpotlightIndexer.shared.indexMemory(id: mem.id, content: mem.content, date: mem.createdAt)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func refresh() async {
        loadMemories()
        // Yield briefly so the caller's progress view can observe the isLoading flip
        try? await Task.sleep(for: .milliseconds(100))
    }

    private func saveMemory() {
        let text = newMemoryText.trimmed
        guard !text.isEmpty else { return }
        do {
            let encrypted = try CryptoHelper.encrypt(text)
            try repo.save(content: encrypted, tags: [context.rawValue, "encrypted"])
            withAnimation(.spring(response: 0.4)) {
                newMemoryText = ""
                loadMemories()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct DecryptedMemory: Identifiable {
    let id: UUID
    let content: String
    let createdAt: Date
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
