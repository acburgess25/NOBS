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
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.vertical, 8)
                }

                Section("Your full name") {
                    TextField("Full name", text: $fullName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.vertical, 8)
                }

                Section("What topics or things matter most to you?") {
                    TextEditor(text: $interests)
                        .frame(minHeight: 80)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .padding(.vertical, 8)
                }

                Section("Any daily habits or routines to keep in mind?") {
                    TextEditor(text: $routines)
                        .frame(minHeight: 80)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .padding(.vertical, 8)
                }

                Section {
                    Button("Save My Profile") {
                        saveProfile()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .background(Color(UIColor.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.vertical, 8)
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