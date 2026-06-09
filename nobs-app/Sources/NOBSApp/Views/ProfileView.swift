import SwiftUI
import NOBSDatabase

struct ProfileView: View {
    @State private var displayName = ""
    @State private var fullName = ""
    @State private var interests = ""
    @State private var routines = ""
    @State private var saved = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var prefs: PreferenceRepository {
        PreferenceRepository(context: .personal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What should NOBS call you?") {
                    TextField("Display name", text: $displayName)
                        .textFieldStyle(.plain)
                }

                Section("Your full name") {
                    TextField("Full name", text: $fullName)
                        .textFieldStyle(.plain)
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
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if saved {
                    Section {
                        Label("Profile saved! NOBS will use this to personalize your experience.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.nobsGreen)
                            .font(NOBSFont.callout())
                    }
                }
            }
            .tint(Color.nobsAccent)
            .navigationTitle("My Profile")
            .task { loadProfile() }
            .alert("Couldn't save profile", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") {}
            } message: { msg in Text(msg) }
        }
    }

    private func loadProfile() {
        displayName = (try? prefs.get(key: "profile.display_name")) ?? ""
        fullName    = (try? prefs.get(key: "profile.full_name"))    ?? ""
        interests   = (try? prefs.get(key: "profile.interests"))    ?? ""
        routines    = (try? prefs.get(key: "profile.routines"))     ?? ""
    }

    private func saveProfile() {
        do {
            try prefs.set(key: "profile.display_name", value: displayName)
            try prefs.set(key: "profile.full_name",    value: fullName)
            try prefs.set(key: "profile.interests",    value: interests)
            try prefs.set(key: "profile.routines",     value: routines)
            saved = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
