import EventKit
import SwiftUI

struct ConversationView: View {
    @StateObject private var model = AppModel()
    @AppStorage("nobs.onboarding.complete") private var onboardingComplete = false
    @State private var draft = ""
    @State private var selectedReceipt: PrivacyReceipt?
    @State private var showNavigation = false

    private let accent = Color(red: 0.31, green: 0.43, blue: 0.20)
    private let canvas = Color(red: 0.975, green: 0.968, blue: 0.945)

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
            handleDeepLink(payload: url.absoluteString)
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
                case .today: TodayView(model: model) { selectedReceipt = $0 }
                case .approvals: ApprovalsView(model: model)
                case .memory: ComingSoonView(title: "Memory", symbol: "brain", detail: "Approved memories will appear here with their source and deletion controls.")
                case .activity: ActivityView(model: model)
                case .home: ComingSoonView(title: "Home", symbol: "house", detail: "Unified Apple Home, Google, and Alexa control is coming soon. No devices are connected yet.")
                case .privacy: PrivacyView(model: model)
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
            Button { Task { await model.refreshProcessingAvailability() } } label: {
                ProcessingRouteBadge(route: model.activeRoute)
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
                                Text(sendingStatusText)
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
                 ? (model.activeRoute == .onDevice && !model.preferTankWhenAvailable
                    ? "Apple Intelligence is ready on this iPhone. Tank is also connected if you need it."
                    : "Tank is connected. Ask me something, or let’s make today realistic.")
                 : (model.onDeviceAvailable
                    ? "Apple Intelligence is ready on this iPhone. Tank chat will reconnect when available."
                    : "I’m working locally. Calendar planning still works; Tank chat will reconnect when available."))
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
                    .background(accent, in: RoundedRectangle(cornerRadius: 12))
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
                .background(entry.role == .user ? accent.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 18))
            if let route = entry.route, let receipt = entry.receipt {
                Button {
                    selectedReceipt = receipt
                } label: {
                    ProcessingRouteBadge(route: route)
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
                ForEach(["What’s on my calendar?", "Help me prioritize today", "Is Tank online?"], id: \.self) { text in
                    Button(text) { Task { await model.send(text) } }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .overlay(Capsule().stroke(accent.opacity(0.35)))
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
                    .background(accent, in: Circle())
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

    private var sendingStatusText: String {
        switch model.activeRoute {
        case .onDevice:
            "Thinking on this iPhone…"
        case .tank:
            "Tank is thinking…"
        case .local:
            "Working locally…"
        case .cloud:
            "NOBScloud is thinking…"
        }
    }

    /// Handles deep-link URLs (e.g. nobs://connect?url=...&token=...).
    /// Also called by PrivacyView's QR scanner for the same payload.
    func handleDeepLink(payload: String) {
        guard let url = URL(string: payload),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        if let tankURL = components.queryItems?.first(where: { $0.name == "url" })?.value {
            model.tankAddress = tankURL
        } else if let device = components.queryItems?.first(where: { $0.name == "device" })?.value {
            model.tankAddress = "http://\(device):8000"
        }
        if let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
            model.tankToken = token
        }
        Task { await model.saveTankConnection() }
    }

    private var dayPart: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "morning"
        case 12..<18: "afternoon"
        default: "evening"
        }
    }
}

private struct OnboardingView: View {
    let onComplete: () -> Void
    @StateObject private var model = AppModel()
    @State private var page = 0
    private let accent = Color(red: 0.31, green: 0.43, blue: 0.20)

    private let pages: [(icon: String, title: String, body: String)] = [
        ("leaf",
         "Your technology.\nFinally working for you.",
         "NOBS helps turn a chaotic day into a realistic plan. Chat stays at the center."),
        ("hand.raised",
         "Private by default.\nClear when it isn't.",
         "Every answer shows whether it was processed on this iPhone, your Tank, or optional NOBScloud."),
    ]

    var body: some View {
        if page < pages.count {
            let p = pages[page]
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image(systemName: p.icon)
                    .font(.system(size: 42))
                    .foregroundStyle(accent)
                Text(p.title)
                    .font(.system(size: 42, weight: .regular, design: .serif))
                Text(p.body)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                Spacer()
                Button("Continue") { withAnimation { page += 1 } }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(28)
        } else {
            // Page 3: Sign in + Tank connect
            SignInView(mode: .onboarding, model: model) { onComplete() }
        }
    }
}

private struct TodayView: View {
    @ObservedObject var model: AppModel
    let onShowReceipt: (PrivacyReceipt) -> Void
    private let accent = Color(red: 0.31, green: 0.43, blue: 0.20)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("A realistic day, not another list.")
                    .font(.system(size: 30, design: .serif))
                briefingCard
                switch model.calendarStatus {
                case .fullAccess, .authorized:
                    if model.isLoadingCalendar {
                        ProgressView("Reading today’s events on this iPhone…")
                    } else if model.events.isEmpty {
                        ContentUnavailableView("Your day is clear", systemImage: "calendar", description: Text("No calendar events remain today."))
                    } else {
                        ForEach(model.events) { event in eventRow(event) }
                        Button("Refresh calendar") { Task { await model.loadToday() } }
                            .buttonStyle(.bordered)
                            .tint(accent)
                    }
                case .denied, .restricted:
                    ContentUnavailableView("Calendar access is off", systemImage: "calendar.badge.exclamationmark", description: Text("Enable Calendar access in Settings to build a real day plan."))
                default:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connect your calendar when its value is clear—not during a wall of setup switches.")
                            .foregroundStyle(.secondary)
                        Button("Allow Calendar access") { Task { await model.requestCalendarAccess() } }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                    }
                    .padding(18)
                    .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                }
                reminderSection
            }
            .padding(20)
        }
    }

    private var briefingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Morning briefing", systemImage: "sunrise")
                .font(.headline)
            if let briefing = model.briefing {
                briefingParagraph("Topline", text: briefing.topline)
                briefingListSection("Priorities", items: briefing.priorities)
                briefingListSection("Conflicts or risks", items: briefing.conflictsOrRisks)
                briefingListSection("Recommended plan", items: briefing.recommendedPlan)
                if let question = briefing.oneUsefulQuestion, !question.isEmpty {
                    briefingParagraph("One useful question", text: question)
                }
                briefingListSection("Suggested next actions", items: briefing.suggestedNextActions)
                HStack(spacing: 10) {
                    Label(briefing.route.rawValue, systemImage: briefing.route == .tank ? "server.rack" : "iphone")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                    Spacer()
                    Button("Privacy receipt") { onShowReceipt(briefing.privacyReceipt) }
                        .font(.caption.weight(.semibold))
                }
            } else {
                Text(briefingDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await model.generateBriefing() }
                } label: {
                    if model.isGeneratingBriefing {
                        ProgressView()
                    } else {
                        Text("Create from \(model.events.count) event\(model.events.count == 1 ? "" : "s") and \(model.reminders.count) reminder\(model.reminders.count == 1 ? "" : "s")")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(model.isGeneratingBriefing || (!model.onDeviceAvailable && !model.tankAvailable))
            }
        }
        .padding(18)
        .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reminders", systemImage: "checklist")
                .font(.headline)
            if model.isLoadingReminders {
                ProgressView("Loading reminder context…")
            } else if model.hasReminderReadAccess {
                if model.reminders.isEmpty {
                    Text("No due reminders for today.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.reminders) { reminder in reminderRow(reminder) }
                    Button("Refresh reminders") { Task { await model.loadReminders() } }
                        .buttonStyle(.bordered)
                        .tint(accent)
                }
            } else {
                Text("Add reminders for better prep and conflict suggestions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Allow Reminders access") { Task { await model.requestReminderAccess() } }
                    .buttonStyle(.bordered)
                    .tint(accent)
            }
        }
        .padding(18)
        .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private func briefingParagraph(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(accent)
            Text(text).font(.subheadline)
        }
    }

    private var briefingDescription: String {
        if model.onDeviceAvailable {
            return "Create a private morning briefing on this iPhone using Apple Intelligence. Visible event titles, times, and calendar context stay local."
        }
        if model.tankAvailable {
            return "Send only the titles, times, and calendar context shown below to your Tank. Notes, attendees, and locations stay off the request."
        }
        return "Apple Intelligence is unavailable and Tank is offline, so NOBS can still show your calendar without sending it anywhere."
    }

    private func briefingListSection(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(accent)
            ForEach(Array(items.prefix(6).enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•").foregroundStyle(accent)
                    Text(item).font(.subheadline)
                }
            }
        }
    }

    private func eventRow(_ event: DayEvent) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(event.start, format: .dateTime.hour().minute())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(event.overlapsNext ? .orange : accent)
                .frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.title).font(.headline)
                    if event.overlapsNext { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                }
                Text(event.calendarName).font(.caption).foregroundStyle(.secondary)
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "location").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func reminderRow(_ reminder: DayReminder) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if let due = reminder.due {
                Text(due, format: .dateTime.hour().minute())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 76, alignment: .leading)
            } else {
                Text("Anytime")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 76, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title).font(.headline)
                Text(reminder.calendarName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct ActivityView: View {
    @ObservedObject var model: AppModel
    private let accent = Color(red: 0.31, green: 0.43, blue: 0.20)

    var body: some View {
        List {
            if model.pendingDecisionCount > 0 {
                Section {
                    Button {
                        model.section = .approvals
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.red, in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(model.pendingDecisionCount) item\(model.pendingDecisionCount == 1 ? "" : "s") need your attention")
                                    .font(.subheadline.weight(.semibold))
                                Text("Go to Approvals →")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("Recent on this device") {
                if model.activity.isEmpty {
                    Text("No activity yet").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.activity.enumerated()), id: \.offset) { _, item in
                        Label(item, systemImage: "checkmark.circle")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

private struct PrivacyView: View {
    @ObservedObject var model: AppModel
    @State private var isScanningQR = false
    private let accent = Color(red: 0.31, green: 0.43, blue: 0.20)

    var body: some View {
        List {
            Section("Processing now") {
                LabeledContent("Chat", value: chatProcessingLabel)
                LabeledContent("On-Device", value: model.onDeviceAvailable ? "Apple Intelligence ready" : "Unavailable")
                LabeledContent("Tank", value: model.tankAvailable ? "Available" : "Unavailable")
                LabeledContent("Calendar", value: "On this iPhone")
            }

            Section {
                Toggle(
                    "Prefer Tank when available",
                    isOn: Binding(
                        get: { model.preferTankWhenAvailable },
                        set: { model.preferTankWhenAvailable = $0 }
                    )
                )
            } header: {
                Text("Routing preference")
            } footer: {
                Text("Default routing is On-Device, then Tank, then Local fallback. Turn this on to use Tank first whenever both are available.")
            }

            // Sign in with Apple section — primary connect method
            Section {
                SignInView(mode: .settings, model: model) {}
            } header: {
                Text("Quick Connect")
            } footer: {
                Text("Sign in once and NOBS automatically reconnects to Tank whenever you're home.")
            }

            Section("Manual Tank Setup") {
                TextField("Tank address", text: $model.tankAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("Device token", text: $model.tankToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    Button(model.tankAvailable ? "Save and check again" : "Save and check connection") {
                        Task { await model.saveTankConnection() }
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: { isScanningQR = true }) {
                        Label("Scan QR", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                }
                Label(
                    model.tankAvailable ? "Connected on your private network" : "Not connected; local fallback is active",
                    systemImage: model.tankAvailable ? "checkmark.circle.fill" : "iphone"
                )
                .foregroundStyle(model.tankAvailable ? accent : .secondary)
            }
            Section("Boundaries") {
                Label("Passwords are off-limits", systemImage: "key.slash")
                Label("Financial accounts are off-limits", systemImage: "creditcard.trianglebadge.exclamationmark")
                Label("No data is sold or used for advertising", systemImage: "eye.slash")
            }
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $isScanningQR) {
            NavigationStack {
                ScannerView(
                    onScan: handleScan,
                    onCancel: { isScanningQR = false }
                )
                .ignoresSafeArea()
                .navigationTitle("Scan Tank QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isScanningQR = false }
                    }
                }
            }
        }
    }

    private func handleScan(payload: String) {
        guard let url = URL(string: payload),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        if let tankURL = components.queryItems?.first(where: { $0.name == "url" })?.value {
            model.tankAddress = tankURL
        } else if let device = components.queryItems?.first(where: { $0.name == "device" })?.value {
            model.tankAddress = "http://\(device):8000"
        }
        if let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
            model.tankToken = token
        }
        isScanningQR = false
        Task { await model.saveTankConnection() }
    }

    private var chatProcessingLabel: String {
        switch model.activeRoute {
        case .onDevice:
            return "On-Device"
        case .tank:
            return model.preferTankWhenAvailable ? "Tank preferred" : "Tank"
        case .local:
            return "Local fallback"
        case .cloud:
            return "NOBScloud"
        }
    }
}

private struct ComingSoonView: View {
    let title: String
    let symbol: String
    let detail: String
    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
    }
}

private struct PrivacyReceiptView: View {
    let receipt: PrivacyReceipt
    var body: some View {
        NavigationStack {
            List {
                receiptSection("Used", values: receipt.used, empty: "Nothing")
                receiptSection("Processed", values: [receipt.processed], empty: "Unknown")
                receiptSection("Shared", values: receipt.shared, empty: "Nothing")
                receiptSection("Changed", values: receipt.changed, empty: "Nothing")
            }
            .navigationTitle("Privacy receipt")
        }
    }

    private func receiptSection(_ title: String, values: [String], empty: String) -> some View {
        Section(title) {
            if values.isEmpty { Text(empty).foregroundStyle(.secondary) }
            else { ForEach(values, id: \.self) { Text($0) } }
        }
    }
}

extension PrivacyReceipt: Identifiable {
    var id: String { "\(processed)|\(used.joined(separator: ","))|\(shared.joined(separator: ","))|\(changed.joined(separator: ","))" }
}

private struct ProcessingRouteBadge: View {
    let route: ProcessingRoute

    private let tankColor = Color(red: 0.31, green: 0.43, blue: 0.20)

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: route.symbolName)
            Text(route.rawValue)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background {
            Capsule().fill(backgroundStyle)
        }
    }

    private var foregroundColor: Color {
        switch route {
        case .local:
            return .secondary
        case .onDevice, .tank, .cloud:
            return .white
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        switch route {
        case .onDevice:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .tank:
            return AnyShapeStyle(tankColor)
        case .local:
            return AnyShapeStyle(Color.black.opacity(0.08))
        case .cloud:
            return AnyShapeStyle(Color.indigo)
        }
    }
}

private extension ProcessingRoute {
    var symbolName: String {
        switch self {
        case .onDevice:
            return "sparkles"
        case .local:
            return "iphone"
        case .tank:
            return "server.rack"
        case .cloud:
            return "icloud"
        }
    }
}

#Preview { ConversationView() }
