import SwiftUI

private enum ProcessingRoute: String {
    case local = "Local"
    case tank = "Tank"
    case cloud = "NOBScloud"
}

private struct ConversationEntry: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
    let route: ProcessingRoute?
}

struct ConversationView: View {
    private let accent = Color(red: 0.31, green: 0.43, blue: 0.20)
    private let canvas = Color(red: 0.975, green: 0.968, blue: 0.945)

    @State private var draft = ""
    @State private var entries: [ConversationEntry] = []
    @State private var isListening = false
    @State private var showSynopsis = false
    @State private var showAddMenu = false
    @State private var showProcessingDetails = false

    private let suggestions = [
        "Summarize my unread emails",
        "Find my notes on planning",
        "What do I have tomorrow?"
    ]

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            header
                            introduction
                            morningHighlight
                            dayDivider
                            userMessage("What’s on my agenda today?")
                            agenda

                            ForEach(entries) { entry in
                                Group {
                                    switch entry.role {
                                    case .user:
                                        userMessage(entry.text)
                                    case .assistant:
                                        assistantMessage(entry.text, route: entry.route ?? .local)
                                    }
                                }
                                .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                    }
                    .onChange(of: entries.count) { _, _ in
                        guard let last = entries.last else { return }
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                suggestionStrip
                composer
            }
        }
        .confirmationDialog("Add context", isPresented: $showAddMenu) {
            Button("Choose a photo") { explainComingSoon("Photo context") }
            Button("Attach a document") { explainComingSoon("Document context") }
            Button("Share my location") { explainComingSoon("Location sharing") }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Processing locally", isPresented: $showProcessingDetails) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("This preview uses only on-device sample data. Nothing is sent to Tank or NOBScloud.")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NOBS")
                        .font(.system(size: 30, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.08))

                    HStack(spacing: 7) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(accent)
                        Text("Local · Private · Yours")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12, weight: .regular))
                }

                Spacer()

                Button { showProcessingDetails = true } label: {
                    Label("Processing locally", systemImage: "checkmark.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Color.black.opacity(0.10))
        }
        .padding(.top, 2)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Good morning, Alex.")
                .font(.system(size: 21, weight: .medium, design: .serif))
                .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.08))

            Text("I’m NOBS. I work on your device, so your conversations stay private and never leave your control.")
            Text("If it helps, I can scan your day and surface what’s worth focusing on.")
        }
        .font(.system(size: 14, weight: .regular))
        .foregroundStyle(.secondary)
        .lineSpacing(2)
        .padding(.top, 11)
    }

    private var morningHighlight: some View {
        Button {
            withAnimation(.snappy) { showSynopsis.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 2)

                VStack(alignment: .leading, spacing: 9) {
                    Label("Morning highlight", systemImage: "sun.max")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)

                    Text("You have a busy day with back-to-back meetings. Your first one starts in 1h 15m.")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineSpacing(2)

                    Label(showSynopsis ? "Hide quick synopsis" : "See a quick synopsis", systemImage: showSynopsis ? "chevron.up" : "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(accent)

                    if showSynopsis {
                        Text("Your morning is meeting-heavy. Protect the 3:15 PM focus block for the client follow-up.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 11)
    }

    private var dayDivider: some View {
        HStack(spacing: 14) {
            Rectangle().fill(Color.black.opacity(0.10)).frame(height: 1)
            Text("Today")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            Rectangle().fill(Color.black.opacity(0.10)).frame(height: 1)
        }
        .padding(.vertical, 11)
    }

    private func userMessage(_ message: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message)
                .font(.system(size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 20))

            Label("9:41 AM", systemImage: "checkmark")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.bottom, 8)
    }

    private func assistantMessage(_ message: String, route: ProcessingRoute) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineSpacing(3)

            Label(route.rawValue, systemImage: route == .local ? "iphone" : "server.rack")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.bottom, 18)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Here’s your day at a glance.")
                .font(.system(size: 14))

            agendaRow(time: "10:00 AM", title: "Design sync", detail: "1h · Video call")
            agendaRow(time: "11:30 AM", title: "Project review", detail: "45m · Conference room")
            agendaRow(time: "1:00 PM", title: "Lunch", detail: "1h · Free")
            agendaRow(time: "2:30 PM", title: "Client update", detail: "30m · Video call")
            agendaRow(time: "3:15 PM", title: "Focus time", detail: "1h 30m · Deep work")
        }
        .padding(.horizontal, 6)
    }

    private func agendaRow(time: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Text(time)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 82, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }

    private var suggestionStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try asking something like")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(accent)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) { send(suggestion) }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().stroke(accent.opacity(0.35), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 10)
        .background(canvas)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            Button { showAddMenu = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.06), in: Circle())
            }

            HStack(spacing: 8) {
                TextField("Ask anything…", text: $draft)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.send)
                    .onSubmit(sendDraft)

                Button { isListening.toggle() } label: {
                    Image(systemName: isListening ? "waveform" : "mic")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(isListening ? Color.red : accent, in: Circle())
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .frame(height: 46)
            .background(Capsule().stroke(Color.black.opacity(0.20), lineWidth: 1))

            Button(action: sendDraft) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : accent)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.06), in: Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func sendDraft() {
        send(draft)
        draft = ""
    }

    private func send(_ message: String) {
        let clean = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        withAnimation(.easeOut) {
            entries.append(ConversationEntry(role: .user, text: clean, route: nil))
        }

        let reply = response(for: clean)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeOut) {
                entries.append(reply)
            }
        }
    }

    private func response(for message: String) -> ConversationEntry {
        let normalized = message.lowercased()

        if normalized.contains("google") || normalized.contains("alexa") || normalized.contains("amazon") {
            return ConversationEntry(
                role: .assistant,
                text: "Full Google Home and Alexa unification is coming soon. Today I can help you plan the routine and prepare its Apple Home version.",
                route: .tank
            )
        }

        if normalized.contains("email") {
            return ConversationEntry(
                role: .assistant,
                text: "Email summaries are coming soon. I can help you define which senders and commitments should count as important without reading any mail yet.",
                route: .local
            )
        }

        if normalized.contains("note") {
            return ConversationEntry(
                role: .assistant,
                text: "Notes access is coming soon. When enabled, I’ll ask before searching and show exactly which notes contributed to an answer.",
                route: .local
            )
        }

        if normalized.contains("tomorrow") || normalized.contains("calendar") {
            return ConversationEntry(
                role: .assistant,
                text: "Calendar access isn’t connected in this preview. Coming soon, I’ll ask for EventKit permission in context and build a realistic plan from your actual schedule.",
                route: .local
            )
        }

        return ConversationEntry(
            role: .assistant,
            text: "I can work through that with you. This preview keeps the conversation local and uses sample context while the live model router is being built.",
            route: .local
        )
    }

    private func explainComingSoon(_ feature: String) {
        withAnimation(.easeOut) {
            entries.append(
                ConversationEntry(
                    role: .assistant,
                    text: "\(feature) is coming soon. Nothing was shared. For now, you can describe the context in chat and I’ll keep it local.",
                    route: .local
                )
            )
        }
    }
}

#Preview {
    ConversationView()
}
