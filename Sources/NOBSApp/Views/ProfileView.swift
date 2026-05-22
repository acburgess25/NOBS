import SwiftUI
import NOBSDatabase

struct ProfileView: View {
    @State private var displayName = ""
    @State private var fullName = ""
    @State private var interests = ""
    @State private var routines = ""
    @State private var saved = false

    private var personalMemories: MemoryRepository {
        MemoryRepository(context: NOBSDatabase.shared.isPersonalModeEnabled ? .personal : .work)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What should the chef call you?") {
                    TextField("Display name", text: $displayName)
                }

                Section("Your full name (for the reservation)") {
                    TextField("Full name", text: $fullName)
                }

                Section("What kind of meals/topics do you like?") {
                    TextEditor(text: $interests)
                        .frame(minHeight: 80)
                }

                Section("Any daily cooking routines?") {
                    TextEditor(text: $routines)
                        .frame(minHeight: 80)
                }

                Section {
                    Button("Save My Preferences") {
                        saveProfile()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if saved {
                    Section {
                        Text("Preferences saved! The chef will use this to prepare your meals.")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("My Preferences")
            .task { loadProfile() }
        }
    }

    private func loadProfile() {
        guard let all = try? personalMemories.fetchAll() else { return }
        for mem in all {
            guard let tags = mem.tags else { continue }
            let tagSet = Set(tags.components(separatedBy: ","))
            if tagSet.contains("display_name") { displayName = mem.content }
            if tagSet.contains("full_name") { fullName = mem.content }
            if tagSet.contains("bio") || tagSet.contains("interests") { interests = mem.content }
            if tagSet.contains("routines") { routines = mem.content }
        }
    }

    private func saveProfile() {
        do {
            try personalMemories.save(content: displayName, tags: ["profile", "display_name", "personal"])
            try personalMemories.save(content: fullName, tags: ["profile", "full_name", "personal"])
            if !interests.isEmpty {
                try personalMemories.save(content: interests, tags: ["profile", "bio", "personal"])
            }
            if !routines.isEmpty {
                try personalMemories.save(content: routines, tags: ["profile", "routines", "personal"])
            }
            saved = true
        } catch {
            print("Failed to save profile: \(error)")
        }
    }
}
