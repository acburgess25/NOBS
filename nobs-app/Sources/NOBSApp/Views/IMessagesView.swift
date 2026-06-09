import SwiftUI
import NOBSiMessage
import NOBSDatabase
import NOBSCore
import ContactsUI

struct IMessagesView: View {
    @State private var contacts: [String] = []
    @State private var selectedContact: String?
    @State private var messageText = ""
    @State private var messages: [String] = []
    @State private var showComposer = false
    @State private var showContactPicker = false
    @State private var newContact = ""
    @State private var context: DataContext = NOBSDatabase.shared.isPersonalModeEnabled ? .personal : .work

    private let handler = iMessageHandler()
    private var history: ConversationHistory {
        ConversationHistory(dataContext: NOBSDatabase.shared.isPersonalModeEnabled ? .personal : .work)
    }

    var body: some View {
        NavigationStack {
            List {
                if let contact = selectedContact {
                    Section {
                        if messages.isEmpty {
                            Text("No messages yet. Send one below.")
                                .foregroundStyle(Color.nobsSecondary)
                                .font(NOBSFont.body())
                        } else {
                            ForEach(messages, id: \.self) { msg in
                                Text(msg)
                                    .font(NOBSFont.body())
                            }
                        }
                    } header: {
                        Text("Conversation with \(contact)").sectionOverline()
                    }
                    .listRowBackground(Color.nobsCard)

                    Section {
                        HStack {
                            TextField("Message...", text: $messageText)
                                .textFieldStyle(.plain)
                                .font(NOBSFont.body())
                            Button {
                                sendMessage(to: contact)
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? AnyShapeStyle(Color.nobsSecondary)
                                        : AnyShapeStyle(Color.nobsAccent))
                            }
                            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.nobsCard)
                } else {
                    Section {
                        ForEach(contacts, id: \.self) { contact in
                            Button {
                                selectedContact = contact
                                loadMessages(from: contact)
                            } label: {
                                HStack(spacing: 12) {
                                    ContactAvatar(name: contact)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact)
                                            .foregroundStyle(Color.nobsPrimary)
                                            .font(NOBSFont.body())
                                        Text("iMessage")
                                            .font(NOBSFont.caption())
                                            .foregroundStyle(Color.nobsSecondary)
                                    }
                                }
                            }
                        }

                        Button {
                            showContactPicker = true
                        } label: {
                            Label("Pick from Contacts", systemImage: "person.crop.circle.badge.plus")
                                .foregroundStyle(Color.nobsAccent)
                        }

                        Button {
                            showComposer = true
                        } label: {
                            Label("New Conversation", systemImage: "plus.circle")
                                .foregroundStyle(Color.nobsAccent)
                        }
                    } header: {
                        Text("Contacts").sectionOverline()
                    }
                    .listRowBackground(Color.nobsCard)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.nobsBg)
            .navigationTitle(selectedContact ?? "iMessage")
            .toolbar {
                if selectedContact != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") {
                            selectedContact = nil
                            messages = []
                        }
                    }
                }
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView { identifier in
                    if !identifier.isEmpty {
                        contacts.insert(identifier, at: 0)
                        selectedContact = identifier
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showComposer) {
                NavigationStack {
                    Form {
                        TextField("Phone or email", text: $newContact)
                            .keyboardType(.emailAddress)
                    }
                    .navigationTitle("New Conversation")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showComposer = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Start") {
                                let c = newContact.trimmingCharacters(in: .whitespaces)
                                if !c.isEmpty {
                                    contacts.insert(c, at: 0)
                                    selectedContact = c
                                    showComposer = false
                                    newContact = ""
                                }
                            }
                            .disabled(newContact.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .presentationDetents([.height(200)])
            }
            .task { loadContacts() }
        }
    }

    private func loadContacts() {
        if contacts.isEmpty {
            // Auto-start with no contacts; user adds via contacts picker or New Conversation
        }
    }

    private func loadMessages(from contact: String) {
        Task {
            do {
                let result = try await handler.readHistory(from: contact)
                messages = result.components(separatedBy: "\n").filter { !$0.isEmpty }
                if messages.isEmpty {
                    messages = ["[Start a new conversation]"]
                }
            } catch {
                messages = ["[Start a new conversation]"]
            }
        }
    }

    private func sendMessage(to contact: String) {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messageText = ""
        Task {
            do {
                let _ = try await handler.send(to: contact, body: text)
                if let url = iMessageHandler.composeURL(to: contact, body: text) {
                    await MainActor.run {
                        UIApplication.shared.open(url)
                    }
                }
                messages.append("[→ \(contact)] \(text)")
            } catch {
                messages.append("[Failed] \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Contact Avatar

private struct ContactAvatar: View {
    let name: String

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.nobsAccent.opacity(0.15))
                .frame(width: 40, height: 40)
            Text(initials)
                .font(NOBSFont.callout())
                .foregroundStyle(Color.nobsAccent)
        }
    }
}

// MARK: - ContactsUI Picker (no authorization required)

private struct ContactPickerView: UIViewControllerRepresentable {
    let onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (String) -> Void

        init(onSelect: @escaping (String) -> Void) {
            self.onSelect = onSelect
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            // Prefer phone number; fall back to email
            if let phone = contact.phoneNumbers.first?.value.stringValue {
                onSelect(phone)
            } else if let email = contact.emailAddresses.first?.value as String? {
                onSelect(email)
            } else {
                let fullName = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                onSelect(fullName)
            }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {}
    }
}

#Preview {
    IMessagesView()
}
