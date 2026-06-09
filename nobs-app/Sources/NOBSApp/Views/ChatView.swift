import SwiftUI
import NOBSAssistant

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    var text: String
    let timestamp = Date()

    enum Role { case user, assistant }
}

struct ChatView: View {
    let assistant: NOBSAssistant

    @State private var messages: [ChatMessage] = []
    @State private var draft: String = ""
    @State private var isThinking = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Spacing.md) {
                            if messages.isEmpty {
                                greeting
                                    .padding(.top, Spacing.xl)
                            } else {
                                ForEach(messages) { m in
                                    MessageBubble(message: m)
                                        .id(m.id)
                                }
                                if isThinking {
                                    ThinkingBubble().id("thinking")
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.md)
                    }
                    .onChange(of: messages.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: isThinking) { _, _ in
                        scrollToBottom(proxy)
                    }
                }

                composer
            }
            .background(Color.nobsBg)
            .navigationTitle("NOBS")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.nobsAccent)
            Text("Ask me anything")
                .font(NOBSFont.title2())
                .foregroundStyle(Color.nobsPrimary)
            Text("I can check your calendar, find contacts, set reminders, and more — just ask.")
                .font(NOBSFont.body())
                .foregroundStyle(Color.nobsSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.sm) {
                ForEach(suggestions, id: \.self) { s in
                    Button { send(text: s) } label: {
                        HStack {
                            Text(s)
                                .font(NOBSFont.body())
                                .foregroundStyle(Color.nobsPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.nobsTertiary)
                        }
                        .padding(.vertical, Spacing.sm + 2)
                        .padding(.horizontal, Spacing.md)
                        .background(Color.nobsCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Spacing.lg)
            .padding(.horizontal, Spacing.md)
        }
    }

    private let suggestions = [
        "What's on my calendar today?",
        "Remind me to call mom at 6pm",
        "Find Sarah's number",
        "What can you do?",
    ]

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            Divider().background(Color.nobsDivider)
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                ZStack(alignment: .leading) {
                    if draft.isEmpty {
                        Text("Message NOBS")
                            .font(NOBSFont.body())
                            .foregroundStyle(Color.nobsTertiary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $draft, axis: .vertical)
                        .focused($inputFocused)
                        .font(NOBSFont.body())
                        .foregroundStyle(Color.nobsPrimary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 10)
                        .lineLimit(1...5)
                        .submitLabel(.send)
                        .onSubmit { sendDraft() }
                }
                .background(Color.nobsCard)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.nobsBorder, lineWidth: 0.5)
                )

                Button(action: sendDraft) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(canSend ? Color.nobsAccent : Color.nobsTertiary)
                        .clipShape(Circle())
                }
                .disabled(!canSend)
                .animation(.easeInOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.sm)
            .background(Color.nobsBg)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        send(text: text)
    }

    private func send(text: String) {
        let userMsg = ChatMessage(role: .user, text: text)
        messages.append(userMsg)
        isThinking = true

        Task {
            let response = await assistant.process(text)
            await MainActor.run {
                isThinking = false
                let assistantMsg = ChatMessage(
                    role: .assistant,
                    text: response.text.isEmpty
                        ? "Sorry — I couldn't come up with a response. Try rephrasing?"
                        : response.text
                )
                messages.append(assistantMsg)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = messages.last?.id else {
            if isThinking { withAnimation { proxy.scrollTo("thinking", anchor: .bottom) } }
            return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(isThinking ? "thinking" : last as AnyHashable, anchor: .bottom)
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(NOBSFont.body())
                .foregroundStyle(message.role == .user ? .white : Color.nobsPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + 2)
                .background(
                    message.role == .user
                        ? AnyShapeStyle(Color.nobsAccent)
                        : AnyShapeStyle(Color.nobsCard)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: 320, alignment: message.role == .user ? .trailing : .leading)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

private struct ThinkingBubble: View {
    @State private var phase = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.nobsTertiary)
                        .frame(width: 6, height: 6)
                        .opacity(phase == i ? 1.0 : 0.35)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 4)
            .background(Color.nobsCard)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 40)
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}
