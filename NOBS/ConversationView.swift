import SwiftUI

struct ConversationView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("nobs.onboarding.complete") private var onboardingComplete = false
    @State private var draft = ""
    @State private var selectedReceipt: PrivacyReceipt?
    @State private var showNavigation = false

    private let accent = Color.nobsAccent
    private let canvas = Color.nobsCanvas
    private let forest = Color.nobsForest
    private let surface = Color.nobsSagePale

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()
            if onboardingComplete {
                mainContent
            } else {
                OnboardingView(onComplete: { onboardingComplete = true })
            }
        }
        .task { await model.start() }
        .onOpenURL { url in
            model.section = .privacy
            model.applyTankPayload(from: url)
            Task { await model.saveTankConnection() }
        }
        .sheet(isPresented: $showNavigation) { navigationSheet }
        .sheet(item: $selectedReceipt) { receipt in
            PrivacyReceiptView(receipt: receipt)
                .presentationDetents([.medium])
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
                Text(model.section.rawValue)
                    .font(.system(size: 22, weight: .medium, design: .serif))
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
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            suggestionStrip
            composer
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Good \(dayPart).")
                .font(.system(size: 30, weight: .regular, design: .serif))
            Text(model.tankAvailable
                 ? "Tank is connected. Ask me something, or let's make today realistic."
                 : "I'm working locally. Calendar planning still works; Tank chat will reconnect when available.")
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
                .font(.body)
                .lineSpacing(3)
                .padding(entry.role == .user ? 12 : 0)
                .background(entry.role == .user ? surface : .clear, in: RoundedRectangle(cornerRadius: 18))
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
                ForEach(["What's on my calendar?", "Help me prioritize today", "Is Tank online?"], id: \.self) { text in
                    Button(text) { Task { await model.send(text) } }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .overlay(Capsule().stroke(Color.nobsGreen.opacity(0.45)))
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 9)
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
            .toolbar { Button("Done") { showNavigation = false } }
        }
        .presentationDetents([.medium, .large])
    }

    private func sendDraft() {
        let text = draft
        draft = ""
        Task { await model.send(text) }
    }

    private var dayPart: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "morning"
        case 12..<18: "afternoon"
        default: "evening"
        }
    }
}

#Preview {
    ConversationView()
        .environmentObject(AppModel())
}
