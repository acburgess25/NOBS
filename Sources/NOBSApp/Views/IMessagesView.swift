import SwiftUI
import NOBSiMessage
import NOBSDatabase
import NOBSCore

struct IMessagesView: View {
    @State private var contacts: [String] = []
    @State private var selectedContact: String?
    @State private var messageText = ""
    @State private var messages: [String] = []
    @State private var showComposer = false
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
                    Section("Conversation with \(contact)") {
                        if messages.isEmpty {
                            Text("No messages yet. Send one below.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(messages, id: \.self) { msg in
                                Text(msg)
                                    .font(.body)
                            }
                        }
                    }

                    Section {
                        HStack {
                            TextField("Message...", text: $messageText)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                sendMessage(to: contact)
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.green)
                            }
                            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                } else {
                    Section("Contacts") {
                        ForEach(contacts, id: \.self) { contact in
                            Button {
                                selectedContact = contact
                                loadMessages(from: contact)
                            } label: {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title2)
                                    VStack(alignment: .leading) {
                                        Text(contact)
                                            .foregroundStyle(.primary)
                                        Text("iMessage")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        Button {
                            showComposer = true
                        } label: {
                            Label("New Conversation", systemImage: "plus.circle")
                        }
                    }
                }
            }
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
        // Load from conversation history stored in memories
        // For now, use defaults
        if contacts.isEmpty {
            // Auto-start with no contacts; user adds via New Conversation
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
                let response = try await handler.send(to: contact, body: text)
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

#Preview {
    IMessagesView()
}
