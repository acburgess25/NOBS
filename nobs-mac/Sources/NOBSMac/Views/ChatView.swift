import SwiftUI

struct ChatView: View {
    @Environment(CommandCenterStore.self) private var store

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(
                        title: "Chat",
                        subtitle: "Talk to the local model stack with NOBS memory in reach."
                    )

                    ForEach(Array(store.chatTranscript.enumerated()), id: \.offset) { _, item in
                        GlassPanel(padding: 14, radius: 18) {
                            Text(item)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(28)
            }

            HStack(spacing: 10) {
                TextField("Ask NOBS", text: $store.localPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit {
                        Task { await store.sendPrompt() }
                    }

                Button {
                    Task { await store.sendPrompt() }
                } label: {
                    Label("Send", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.localPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isWorking)
            }
            .padding()
            .background(.bar)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
