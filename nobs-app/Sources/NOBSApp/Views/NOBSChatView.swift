import SwiftUI
import NOBSAssistant

public struct NOBSChatView: View {
    let assistant: NOBSAssistant

    @State private var messages: [ChatBubble] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var processingTask: Task<Void, Never>?

    private let suggestions = [
        "Save a memory",
        "Add a task for me",
        "List my reminders",
        "Turn on the lights",
    ]

    public init(assistant: NOBSAssistant) {
        self.assistant = assistant
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesArea
                Divider()
                inputBar
                    .padding(.bottom, 4)
            }
            .background(Color.nobsBg)
            .onDisappear { cancelPendingRequest() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: Spacing.xs) {
                        NobsLogo(size: 26)
                        Text("NOBS")
                            .font(NOBSFont.headline())
                            .foregroundStyle(Color.nobsPrimary)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.spring(response: 0.3)) { messages.removeAll() }
                        Task { await assistant.resetSession() }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Color.nobsAccent)
                    }
                    .accessibilityLabel("New conversation")
                }
            }
        }
    }

    // MARK: - Messages

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    if messages.isEmpty {
                        emptyState
                            .padding(.top, Spacing.xxl)
                    }
                    ForEach(messages) { bubble in
                        ChatBubbleView(bubble: bubble)
                            .id(bubble.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if isProcessing {
                        TypingIndicatorView()
                            .id("typing")
                            .transition(.opacity)
                    }
                    Color.clear.frame(height: 1).id("scroll-bottom")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: messages.count)
                .animation(.easeInOut(duration: 0.2), value: isProcessing)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo("scroll-bottom") }
            }
            .onChange(of: isProcessing) { _, new in
                if new { withAnimation { proxy.scrollTo("typing") } }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.xl) {
            NobsLogo(size: 80)
                .nobsShadow(strong: true)

            VStack(spacing: Spacing.sm) {
                Text("What can I help with?")
                    .font(NOBSFont.title2())
                    .foregroundStyle(Color.nobsPrimary)
                Text("Save memories, manage tasks,\ncontrol your home, or just chat.")
                    .font(NOBSFont.body())
                    .foregroundStyle(Color.nobsSecondary)
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        inputText = suggestion
                        send()
                    } label: {
                        Text(suggestion)
                            .font(NOBSFont.footnote())
                            .foregroundStyle(Color.nobsAccent)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.nobsAccent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            TextField("Ask NOBS anything…", text: $inputText, axis: .vertical)
                .font(NOBSFont.body())
                .lineLimit(1...5)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .background(Color.nobsCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                .nobsShadow()
                .onSubmit { send() }

            Button { send() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(
                        (inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                            ? AnyShapeStyle(Color.nobsTertiary)
                            : AnyShapeStyle(Color.nobsAccent)
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.nobsBg)
    }

    // MARK: - Send

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }
        inputText = ""
        withAnimation { messages.append(ChatBubble(role: .user, text: text)) }
        isProcessing = true

        processingTask = Task {
            let response = await assistant.process(text)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation {
                    isProcessing = false
                    messages.append(ChatBubble(role: .assistant, text: response.text))
                }
            }
        }
    }
}

// MARK: - View lifecycle extension

extension NOBSChatView {
    func cancelPendingRequest() {
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false
    }
}

// MARK: - Data Model

public struct ChatBubble: Identifiable {
    public let id = UUID()
    public let role: BubbleRole
    public var text: String
    public enum BubbleRole { case user, assistant }

    public init(role: BubbleRole, text: String) {
        self.role = role
        self.text = text
    }
}

// MARK: - Bubble View

private struct ChatBubbleView: View {
    let bubble: ChatBubble

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            if bubble.role == .user { Spacer(minLength: 60) }

            if bubble.role == .assistant {
                NobsLogo(size: 30)
                    .padding(.bottom, 2)
            }

            Text(bubble.text)
                .font(NOBSFont.body())
                .foregroundStyle(bubble.role == .user ? .white : Color.nobsPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .background(bubble.role == .user ? Color.nobsAccent : Color.nobsCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                .nobsShadow()
                .textSelection(.enabled)

            if bubble.role == .assistant { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            NobsLogo(size: 30).padding(.bottom, 2)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.nobsTertiary)
                        .frame(width: 8, height: 8)
                        .offset(y: animating ? -5 : 0)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 14)
            .background(Color.nobsCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            .nobsShadow()
            .onAppear { animating = true }

            Spacer(minLength: 60)
        }
    }
}
