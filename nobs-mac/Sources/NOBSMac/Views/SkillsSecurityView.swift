import SwiftUI

struct SkillsSecurityView: View {
    @State private var requireManifest = true
    @State private var sandboxByDefault = true
    @State private var blockBroadAccess = true
    @State private var learnSafePatterns = true

    private let gates = [
        ("Source", "Who published it, where updates come from, and whether the code can be inspected.", "checkmark.seal"),
        ("Permissions", "Files, network, contacts, reminders, calendar, messages, microphone, photos, and family data.", "hand.raised"),
        ("Secrets", "No tokens in logs, memory, prompts, screenshots, or exported text files.", "key"),
        ("Execution", "Sandboxed helpers, least privilege, signed binaries, and no surprise background jobs.", "terminal"),
        ("Network", "ATS/TLS expectations, clear domains, no unknown telemetry, and offline behavior.", "network"),
        ("Learning", "Compress only safe implementation patterns into memory after user approval.", "brain.head.profile")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(
                    title: "Skills",
                    subtitle: "Public skills and tools can be useful, but NOBS treats them like software entering an Apple-grade trust boundary."
                )

                GlassPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Security policy")
                            .font(.headline)

                        Toggle(isOn: $requireManifest) {
                            Label("Require a plain-language permission manifest before install", systemImage: "doc.badge.gearshape")
                        }

                        Toggle(isOn: $sandboxByDefault) {
                            Label("Run public tools sandboxed and least-privilege by default", systemImage: "shippingbox")
                        }

                        Toggle(isOn: $blockBroadAccess) {
                            Label("Block broad access requests unless the user explicitly approves the exact reason", systemImage: "lock.trianglebadge.exclamationmark")
                        }

                        Toggle(isOn: $learnSafePatterns) {
                            Label("Learn implementation patterns only after the tool passes review", systemImage: "sparkles")
                        }
                    }
                    .toggleStyle(.switch)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                    ForEach(gates, id: \.0) { gate in
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: gate.2)
                                    .font(.title2)
                                    .foregroundStyle(Color.nobsBlue)

                                Text(gate.0)
                                    .font(.headline)

                                Text(gate.1)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Implementation ladder")
                            .font(.headline)

                        Label("Inspect public skill metadata and source before it touches user data.", systemImage: "1.circle")
                        Label("Generate a capability manifest and risk score the person can understand.", systemImage: "2.circle")
                        Label("Run the tool in an isolated helper or local server with narrow file and network scope.", systemImage: "3.circle")
                        Label("Ask for confirmation before enabling data access or actions.", systemImage: "4.circle")
                        Label("Distill the safe pattern into simple iCloud memory so NOBS can implement it locally next time.", systemImage: "5.circle")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
