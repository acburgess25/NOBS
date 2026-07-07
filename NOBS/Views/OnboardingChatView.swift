import SwiftUI

struct OnboardingChatView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onComplete: () -> Void

    @State private var step: Step = .name
    @State private var messages: [OnboardingMessage] = []
    @State private var nameDraft = ""
    @State private var problemDraft = ""
    @State private var selectedLoads: Set<String> = []

    private let accent = Color.nobsAccent
    private let forest = Color.nobsForest
    private let surface = Color.nobsSagePale

    private let loadOptions = ["Work", "Home", "Health", "Family", "Other"]
    private let hourPresets: [(label: String, start: String?, end: String?)] = [
        ("9–5", "09:00", "17:30"),
        ("Early bird", "06:00", "15:00"),
        ("Night owl", "11:00", "20:00"),
        ("Skip", nil, nil),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(messages) { message in
                            onboardingBubble(message)
                                .id(message.id)
                        }
                        if step.showsTextField {
                            textInputArea
                        }
                        if step.showsLoadChips {
                            loadChipArea
                        }
                        if step.showsHourChips {
                            hourChipArea
                        }
                        if step.showsProactivityChips {
                            proactivityChipArea
                        }
                        if step.showsResponseLengthChips {
                            responseLengthChipArea
                        }
                    }
                    .padding(20)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        if reduceMotion {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        } else {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .onAppear(perform: begin)
        .nobsScreenBackground()
    }

    private func begin() {
        guard messages.isEmpty else { return }
        appendAssistant("Hi — I'm NOBS. Let's keep this short. What should I call you?")
    }

    private func onboardingBubble(_ message: OnboardingMessage) -> some View {
        Text(message.text)
            .font(.body)
            .lineSpacing(3)
            .padding(message.role == .user ? 12 : 0)
            .background(message.role == .user ? surface : .clear, in: RoundedRectangle(cornerRadius: 18))
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            .accessibilityLabel(message.role == .user ? "You said: \(message.text)" : "NOBS says: \(message.text)")
    }

    private var textInputArea: some View {
        HStack(spacing: 10) {
            TextField(step.placeholder, text: step == .name ? $nameDraft : $problemDraft, axis: .vertical)
                .lineLimit(1...3)
                .padding(.horizontal, 15)
                .frame(minHeight: 46)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                .submitLabel(.send)
                .onSubmit(submitText)
            Button(action: submitText) {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(forest, in: Circle())
            }
            .disabled(currentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(currentDraft.isEmpty ? 0.5 : 1)
            .accessibilityLabel("Send answer")
        }
        .padding(.top, 8)
    }

    private var loadChipArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowChipLayout(options: loadOptions, selection: $selectedLoads)
            HStack {
                Button("Skip") { advanceFromMentalLoad(skipped: true) }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Continue") { advanceFromMentalLoad(skipped: false) }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .disabled(selectedLoads.isEmpty)
            }
        }
        .padding(.top, 8)
    }

    private var hourChipArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(hourPresets, id: \.label) { preset in
                Button(preset.label) { advanceFromWorkingHours(preset) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 8)
    }

    private var proactivityChipArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(ProactivityLevel.allCases, id: \.self) { level in
                Button(level.title) { advanceFromProactivity(level) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 8)
    }

    private var responseLengthChipArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(ResponseLength.allCases, id: \.self) { length in
                Button(length.title) { advanceFromResponseLength(length) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint(responseLengthHint(length))
            }
        }
        .padding(.top, 8)
    }

    private var currentDraft: String {
        step == .name ? nameDraft : problemDraft
    }

    private func submitText() {
        let text = currentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        switch step {
        case .name:
            appendUser(text)
            nameDraft = ""
            model.updateProfile { $0.displayName = text }
            step = .mentalLoad
            appendAssistant("What usually creates mental load — work, home, health, or something else? Pick any that apply.")
        case .immediateProblem:
            appendUser(text)
            problemDraft = ""
            model.updateProfile { $0.immediateProblem = text }
            finishOnboarding()
        default:
            break
        }
    }

    private func advanceFromMentalLoad(skipped: Bool) {
        if skipped {
            appendUser("Skip")
        } else {
            appendUser(selectedLoads.sorted().joined(separator: ", "))
            model.updateProfile { $0.mentalLoadSources = Array(selectedLoads).sorted() }
        }
        step = .workingHours
        appendAssistant("When do you usually start and finish your working day?")
    }

    private func advanceFromWorkingHours(_ preset: (label: String, start: String?, end: String?)) {
        appendUser(preset.label)
        model.updateProfile {
            $0.workingHoursStart = preset.start
            $0.workingHoursEnd = preset.end
        }
        step = .proactivity
        appendAssistant("How proactive should I be — quiet, balanced, or proactive check-ins?")
    }

    private func advanceFromProactivity(_ level: ProactivityLevel) {
        appendUser(level.title)
        model.updateProfile { $0.proactivityLevel = level }
        step = .responseLength
        appendAssistant("How much detail do you want in plans and answers — brief, standard, or detailed?")
    }

    private func advanceFromResponseLength(_ length: ResponseLength) {
        appendUser(length.title)
        model.updateProfile { $0.accessibilityPreferences.responseLength = length }
        step = .immediateProblem
        appendAssistant("What's one thing I could help with today?")
    }

    private func finishOnboarding() {
        step = .done
        let name = model.profile.greetingName ?? "there"
        let detail = model.profile.accessibilityPreferences.responseLength.title.lowercased()
        appendAssistant("Good to meet you, \(name). I'll keep things \(model.profile.proactivityLevel.title.lowercased()) with \(detail) answers, and private by default.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onComplete()
        }
    }

    private func appendAssistant(_ text: String) {
        messages.append(OnboardingMessage(role: .assistant, text: text))
    }

    private func responseLengthHint(_ length: ResponseLength) -> String {
        switch length {
        case .brief: "Shows fewer items in Today and shorter summaries"
        case .standard: "Balanced detail for most days"
        case .detailed: "Shows more context in plans and lists"
        }
    }

    private func appendUser(_ text: String) {
        messages.append(OnboardingMessage(role: .user, text: text))
    }
}

private struct OnboardingMessage: Identifiable {
    enum Role {
        case assistant
        case user
    }

    let id = UUID()
    let role: Role
    let text: String
}

private enum Step {
    case name
    case mentalLoad
    case workingHours
    case proactivity
    case responseLength
    case immediateProblem
    case done

    var showsTextField: Bool {
        self == .name || self == .immediateProblem
    }

    var showsLoadChips: Bool { self == .mentalLoad }
    var showsHourChips: Bool { self == .workingHours }
    var showsProactivityChips: Bool { self == .proactivity }
    var showsResponseLengthChips: Bool { self == .responseLength }

    var placeholder: String {
        switch self {
        case .name: "Your name"
        case .immediateProblem: "One thing on your mind"
        default: ""
        }
    }
}

private struct FlowChipLayout: View {
    let options: [String]
    @Binding var selection: Set<String>
    private let accent = Color.nobsAccent

    var body: some View {
        FlexibleChipGrid(options: options, selection: selection) { option in
            Button {
                if selection.contains(option) {
                    selection.remove(option)
                } else {
                    selection.insert(option)
                }
            } label: {
                Text(option)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        selection.contains(option) ? accent.opacity(0.18) : Color.clear,
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(selection.contains(option) ? accent : Color.nobsGreen.opacity(0.45)))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selection.contains(option) ? .isSelected : [])
        }
    }
}

private struct FlexibleChipGrid<Content: View>: View {
    let options: [String]
    let selection: Set<String>
    let content: (String) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunked(options, size: 2), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { option in
                        content(option)
                    }
                }
            }
        }
    }

    private func chunked(_ values: [String], size: Int) -> [[String]] {
        stride(from: 0, to: values.count, by: size).map {
            Array(values[$0..<min($0 + size, values.count)])
        }
    }
}

#Preview {
    OnboardingChatView(onComplete: {})
        .environmentObject(AppModel())
}
