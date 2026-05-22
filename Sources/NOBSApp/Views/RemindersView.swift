import SwiftUI
import NOBSReminders
import NOBSCore
import NOBSDatabase

struct RemindersView: View {
    @State private var context: DataContext = NOBSDatabase.shared.isPersonalModeEnabled ? .personal : .work
    @State private var reminders: [ReminderItem] = []
    @State private var newTitle = ""
    @State private var newDueDate = Date()
    @State private var showDatePicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false

    private let handler = RemindersHandler()

    var body: some View {
        NavigationStack {
            List {
                if let msg = errorMessage {
                    Text(msg)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Section("Pending") {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                    ForEach(reminders.filter { !$0.isCompleted }, id: \.id) { reminder in
                        HStack {
                            Button {
                                completeReminder(reminder)
                            } label: {
                                Image(systemName: "circle")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading) {
                                Text(reminder.title)
                                if let due = reminder.dueDate {
                                    Text(due, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if reminders.contains(where: \.isCompleted) {
                    Section("Completed") {
                        ForEach(reminders.filter(\.isCompleted), id: \.id) { reminder in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(reminder.title)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                if NOBSDatabase.shared.isPersonalModeEnabled {
                    ToolbarItem(placement: .principal) {
                        Picker("Context", selection: $context) {
                            Text("Personal").tag(DataContext.personal)
                            Text("Work").tag(DataContext.work)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: context) { _, _ in loadReminders() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {
                        showCreateSheet = true
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    Form {
                        TextField("Title", text: $newTitle)
                        DatePicker("Due Date", selection: $newDueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    .navigationTitle("New Reminder")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showCreateSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                createReminder()
                                showCreateSheet = false
                            }
                            .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .task { loadReminders() }
            .refreshable { loadReminders() }
        }
    }

    private func loadReminders() {
        isLoading = true
        Task {
            do {
                reminders = try await handler.list(context: context)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func createReminder() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let item = ReminderItem(title: title, dueDate: newDueDate, dataContext: context)
        Task {
            do {
                try await handler.create(item)
                newTitle = ""
                loadReminders()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func completeReminder(_ reminder: ReminderItem) {
        Task {
            do {
                try await handler.complete(id: reminder.id)
                loadReminders()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
