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
                Section("What should NOBS call you?") {
                    TextField("Display name", text: $displayName)
                }

                Section("Your full name") {
                    TextField("Full name", text: $fullName)
                }

                Section("What topics or things matter most to you?") {
                    TextEditor(text: $interests)
                        .frame(minHeight: 80)
                }

                Section("Any daily habits or routines to keep in mind?") {
                    TextEditor(text: $routines)
                        .frame(minHeight: 80)
                }

                Section {
                    Button("Save My Profile") {
                        saveProfile()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if saved {
                    Section {
                        Text("Profile saved! NOBS will use this to personalize your experience.")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("My Profile")
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
