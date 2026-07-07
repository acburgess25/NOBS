import SwiftUI

struct ConversationView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ""
    @State private var selectedReceipt: PrivacyReceipt?
    @State private var showNavigation = false

    private let accent = Color.nobsAccent
    private let canvas = Color.nobsCanvas
    private let forest = Color.nobsForest
    private let surface = Color.nobsSagePale

    private var responseLength: ResponseLength {
        model.profile.accessibilityPreferences.responseLength
    }

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()
            if model.needsOnboarding {
                OnboardingView(onComplete: { model.completeOnboarding() })
            } else {
                mainContent
            }
        }
        .task { await model.start() }
        .onChange(of: model.needsOnboarding) { _, needsOnboarding in
            guard !needsOnboarding, let prompt = model.consumePendingChatPrompt() else { return }
            draft = prompt
        }
        .onChange(of: model.pendingChatPrompt) { _, prompt in
            guard let prompt, !prompt.isEmpty else { return }
            draft = prompt
        }
        .onOpenURL { url in
            model.handleDeepLink(url)
        }
        .sheet(isPresented: $showNavigation) { navigationSheet }
        .sheet(item: $selectedReceipt) { receipt in
            PrivacyReceiptView(receipt: receipt)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $model.showConflictSheet) {
            if let conflict = model.clarifyingConflict {
                ConflictResolutionSheet(conflict: conflict) { option in
                    model.resolveConflict(choosing: option)
                }
                .presentationDetents([.medium])
            }
        }
        .alert("NOBS", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "")
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch model.section {
                case .chat: chat
                case .today: TodayView { selectedReceipt = $0 }
                case .approvals: ApprovalsView()
                case .memory: ComingSoonView(title: "Memory", symbol: "brain", detail: "Approved memories will appear here with their source and deletion controls.")
                case .activity: ActivityView { selectedReceipt = $0 }
                case .home: ComingSoonView(title: "Home", symbol: "house", detail: "Unified Apple Home, Google, and Alexa control is coming soon. No devices are connected yet.")
                case .privacy: PrivacyView()
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { showNavigation = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal")
                        .frame(width: 40, height: 40)
                    if model.pendingDecisionCount > 0 {
                        Text("\(model.pendingDecisionCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.red, in: Circle())
                            .offset(x: 6, y: -4)
                    }
                }
            }
            .accessibilityLabel("Open navigation\(model.pendingDecisionCount > 0 ? ", \(model.pendingDecisionCount) items need your attention" : "")")

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 8) {
                    Text(model.section.rawValue)
                        .font(.system(size: 22, weight: .medium, design: .serif))
                    NOBSBetaBadge()
                }
                Text("NOBS · Private by design")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await model.refreshTankStatus() } } label: {
                Label(
                    model.tankAvailable ? "Tank" : "Local",
                    systemImage: model.tankAvailable ? "server.rack" : "iphone"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(forest)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(surface, in: Capsule())
            }
            .accessibilityHint("Checks the current processing connection")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(canvas)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var chat: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        welcome
                        ForEach(model.entries) { entry in
                            message(entry)
                                .id(entry.id)
                        }
                        if model.isSending {
                            HStack(spacing: 9) {
                                ProgressView().tint(accent)
                                Text(model.tankAvailable ? "Tank is thinking…" : "Working locally…")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: model.entries.count) { _, _ in
                    if let last = model.entries.last {
                        if reduceMotion {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        } else {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
            suggestionStrip
            composer
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.personalizedDayPartGreeting)
                .font(.system(size: 30, weight: .regular, design: .serif))
                .accessibilityAddTraits(.isHeader)
            Text(welcomeDetail)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
            Button {
                model.section = .today
            } label: {
                Label("Plan my day", systemImage: "sun.max")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(forest, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private func message(_ entry: ConversationEntry) -> some View {
        VStack(alignment: entry.role == .user ? .trailing : .leading, spacing: 6) {
            Text(entry.text)
                .font(entry.role == .assistant ? assistantMessageFont : .body)
                .lineSpacing(messageLineSpacing)
                .padding(entry.role == .user ? 12 : 0)
                .background(entry.role == .user ? surface : .clear, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel(entry.role == .user ? "You said: \(entry.text)" : "NOBS says: \(entry.text)")
            if let route = entry.route {
                Button {
                    selectedReceipt = entry.receipt
                } label: {
                    Label(route.rawValue, systemImage: route == .tank ? "server.rack" : "iphone")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows the privacy receipt for this response")
            }
        }
        .frame(maxWidth: .infinity, alignment: entry.role == .user ? .trailing : .leading)
    }

    private var suggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.chatSuggestions, id: \.self) { text in
                    Button(text) { Task { await model.send(text) } }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .overlay(Capsule().stroke(Color.nobsGreen.opacity(0.45)))
                        .accessibilityHint("Sends this prompt to NOBS")
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 9)
        .accessibilityLabel("Suggested prompts")
    }

    private var assistantMessageFont: Font {
        switch responseLength {
        case .brief: .subheadline
        case .standard, .detailed: .body
        }
    }

    private var messageLineSpacing: CGFloat {
        switch responseLength {
        case .brief: 2
        case .standard: 3
        case .detailed: 5
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Ask NOBS…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 15)
                .frame(minHeight: 46)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                .submitLabel(.send)
                .onSubmit(sendDraft)
            Button(action: sendDraft) {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(forest, in: Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSending)
            .opacity(draft.isEmpty ? 0.5 : 1)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var navigationSheet: some View {
        NavigationStack {
            List(AppSection.allCases) { section in
                Button {
                    model.section = section
                    showNavigation = false
                } label: {
                    HStack {
                        Label(section.rawValue, systemImage: section.symbol)
                            .foregroundStyle(section == model.section ? accent : .primary)
                        Spacer()
                        if section == .approvals, model.pendingDecisionCount > 0 {
                            Text("\(model.pendingDecisionCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.red, in: Capsule())
                        }
                    }
                }
            }
            .navigationTitle("NOBS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.nobsCanvas, for: .navigationBar)
            .toolbar { Button("Done") { showNavigation = false } }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.nobsCanvas)
    }

    private var welcomeDetail: String {
        if responseLength == .brief {
            if model.tankAvailable {
                return "Tank connected. Ask anything or open Today."
            }
            return "Working locally. Calendar planning on Today still works."
        }
        if model.tankAvailable {
            return "Tank is connected. Ask me something, or let's make today realistic."
        }
        return "I'm working locally. Calendar planning still works; Tank chat will reconnect when available."
    }

    private func sendDraft() {
        let text = draft
        draft = ""
        Task { await model.send(text) }
    }
}

#Preview {
    ConversationView()
        .environmentObject(AppModel())
}
