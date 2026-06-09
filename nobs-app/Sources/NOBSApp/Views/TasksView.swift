import SwiftUI
import NOBSDatabase
import NOBSCore

struct TasksView: View {
    @State private var context: DataContext = NOBSDatabase.shared.isPersonalModeEnabled ? .personal : .work
    @State private var tasks: [UserTaskMO] = []
    @State private var newTaskTitle = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var flaggedIDs: Set<UUID> = []

    private let haptics = HapticManager.shared

    private var repo: TaskRepository {
        TaskRepository(context: context)
    }

    var body: some View {
        NavigationStack {
            List {
                inputSection
                pendingSection
                completedSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.nobsBg)
            .navigationTitle("Tasks")
            .toolbar {
                if NOBSDatabase.shared.isPersonalModeEnabled {
                    contextPicker
                }
            }
            .task { loadTasks() }
            .refreshable { loadTasks() }
            .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK") {}
            } message: { msg in
                Text(msg)
            }
            .overlay { emptyOverlay }
        }
    }

    private var inputSection: some View {
        Section {
            HStack(spacing: 8) {
                TextField("New task...", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(NOBSFont.body())
                Button {
                    withAnimation(.spring(response: 0.3)) { addTask() }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newTaskTitle.trimmed.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.nobsAccent))
                        .padding(4)
                        .glassEffect(.regular.tint(Color.nobsAccent).interactive(), in: Circle())
                }
                .disabled(newTaskTitle.trimmed.isEmpty)
                .sensoryFeedback(.success, trigger: tasks.count)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.nobsCard)
    }

    private var pendingSection: some View {
        Section {
            if isLoading && tasks.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            }

            let allTasks = self.tasks
            ForEach(allTasks, id: \UserTaskMO.id) { (task: UserTaskMO) in
                if !task.isCompleted {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.3)) { completeTask(task) }
                        } label: {
                            Image(systemName: "circle")
                                .font(.title3)
                                .foregroundStyle(Color.nobsAccent)
                                .contentTransition(.symbolEffect(.automatic))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.success, trigger: task.isCompleted)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(NOBSFont.body())
                            if let due = task.dueDate {
                                Label(due.formatted(date: .abbreviated, time: .shortened),
                                      systemImage: "clock")
                                    .font(.caption)
                                    .foregroundStyle(Color.nobsSecondary)
                            }
                        }

                        Spacer()

                        if flaggedIDs.contains(task.id) {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(Color.nobsAccent)
                        }
                    }
                    .padding(.vertical, 2)
                    .transition(.slide.combined(with: .opacity))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                haptics.taskCompleted()
                                completeTask(task)
                            }
                        } label: {
                            Label("Complete", systemImage: "checkmark")
                        }
                        .tint(Color.nobsGreen)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            haptics.destructiveAction()
                            deleteTask(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            toggleFlag(task)
                        } label: {
                            Label(flaggedIDs.contains(task.id) ? "Unflag" : "Flag",
                                  systemImage: flaggedIDs.contains(task.id) ? "flag.slash" : "flag")
                        }
                        .tint(Color.nobsAccent)
                    }
                }
            }
        } header: {
            Text("Pending").sectionOverline()
        }
        .listRowBackground(Color.nobsCard)
    }

    private var completedSection: some View {
        let allTasks = self.tasks
        let hasCompleted = allTasks.contains { $0.isCompleted }
        if !hasCompleted {
            return AnyView(EmptyView())
        }
        return AnyView(Section {
            ForEach(allTasks, id: \UserTaskMO.id) { (task: UserTaskMO) in
                if task.isCompleted {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.nobsGreen)
                            .contentTransition(.symbolEffect(.automatic))
                        VStack(alignment: .leading) {
                            Text(task.title)
                                .strikethrough()
                                .foregroundStyle(Color.nobsSecondary)
                            if let due = task.dueDate {
                                Text(due.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(Color.nobsTertiary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            haptics.destructiveAction()
                            deleteTask(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Completed").sectionOverline()
        }
        .listRowBackground(Color.nobsCard))
    }

    @ViewBuilder
    private var emptyOverlay: some View {
        if !isLoading && tasks.isEmpty {
            ContentUnavailableView(
                "No Tasks",
                systemImage: "checklist",
                description: Text("Add your first task above. Tasks are stored locally and synced on demand.")
            )
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
                withAnimation { loadTasks() }
            }
        }
    }

    private func loadTasks() {
        isLoading = true
        errorMessage = nil
        do {
            tasks = try repo.fetchPending()
            // Keep Spotlight index in sync with pending tasks
            for task in tasks {
                SpotlightIndexer.shared.indexTask(id: task.id, title: task.title, dueDate: task.dueDate)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func addTask() {
        let title = newTaskTitle.trimmed
        guard !title.isEmpty else { return }
        do {
            try repo.create(title: title)
            haptics.taskCreated()
            withAnimation(.spring(response: 0.4)) {
                newTaskTitle = ""
                loadTasks()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func completeTask(_ task: UserTaskMO) {
        do {
            try repo.complete(id: task.id)
            haptics.taskCompleted()
            // Remove from Spotlight — completed tasks don't need to surface in search
            SpotlightIndexer.shared.remove(id: "task-\(task.id.uuidString)")
            withAnimation { loadTasks() }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteTask(_ task: UserTaskMO) {
        do {
            try repo.delete(id: task.id)
            SpotlightIndexer.shared.remove(id: "task-\(task.id.uuidString)")
            withAnimation { loadTasks() }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func toggleFlag(_ task: UserTaskMO) {
        haptics.selectionChanged()
        withAnimation(.spring(response: 0.25)) {
            if flaggedIDs.contains(task.id) {
                flaggedIDs.remove(task.id)
            } else {
                flaggedIDs.insert(task.id)
            }
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
