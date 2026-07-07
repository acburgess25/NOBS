import SwiftUI

struct ConflictResolutionSheet: View {
    let conflict: ClarifyingConflict
    let onChoose: (ClarifyingConflict.Option) -> Void

    private let accent = Color.nobsAccent
    private let surface = Color.nobsSagePale

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(conflict.question)
                    .font(.title3)
                    .lineSpacing(4)
                Text("NOBS will not change your calendar until you confirm in chat.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(spacing: 12) {
                    choiceButton(conflict.optionA)
                    choiceButton(conflict.optionB)
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Schedule conflict")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func choiceButton(_ option: ClarifyingConflict.Option) -> some View {
        Button {
            onChoose(option)
        } label: {
            HStack {
                Text(option.label)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(accent)
            }
            .padding(16)
            .background(surface, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ConflictResolutionSheet(
        conflict: ClarifyingConflict(
            question: "Which meeting is must-attend?",
            optionA: .init(id: "a", label: "Design sync", eventID: "1"),
            optionB: .init(id: "b", label: "School pickup", eventID: "2")
        ),
        onChoose: { _ in }
    )
}
