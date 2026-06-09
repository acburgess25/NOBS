import SwiftUI

struct TankView: View {
    @Environment(CommandCenterStore.self) private var store
    @State private var requiresIdentityCheck = true
    @State private var collectFirstLastName = true
    @State private var collectSelfie = true
    @State private var manualReview = true
    @State private var deleteWhenNoLongerNeeded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(
                    title: "Tank",
                    subtitle: "Free hosted agent runtime for beta testers, with local-first behavior whenever their own machine is available."
                )

                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            StatusPulse(tint: .nobsAmber)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Beta hosting policy")
                                    .font(.headline)
                                Text("Testers can run services on Tank for free during beta. Production tiers only charge when hosted compute is actually needed.")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        Text("Runtime order")
                            .font(.headline)

                        Label("Use the user's MacBook or Linux box when available.", systemImage: "1.circle")
                        Label("Wake Tank services only for beta hosted jobs or unavailable local machines.", systemImage: "2.circle")
                        Label("When disconnected, keep useful work local and relay to the phone over Bluetooth where possible.", systemImage: "3.circle")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tank beta approval")
                            .font(.headline)

                        Toggle(isOn: $requiresIdentityCheck) {
                            Label("Require approval only when the person chooses Tank hosted runtime", systemImage: "checkmark.seal")
                        }

                        Toggle(isOn: $collectFirstLastName) {
                            Label("Collect first and last name for the beta application", systemImage: "person.text.rectangle")
                        }

                        Toggle(isOn: $collectSelfie) {
                            Label("Collect a selfie for hosted access review", systemImage: "camera.viewfinder")
                        }

                        Toggle(isOn: $manualReview) {
                            Label("Require manual review before showing the approval badge", systemImage: "person.crop.circle.badge.checkmark")
                        }

                        Toggle(isOn: $deleteWhenNoLongerNeeded) {
                            Label("Delete verification data when it is no longer needed", systemImage: "trash")
                        }

                        Divider()

                        Label("Local-only users do not need the Tank approval badge.", systemImage: "macbook")
                        Label("Do not create face templates or run hidden face recognition for beta approval.", systemImage: "eye.slash")
                        Label("Explain the purpose and get consent before collecting name or selfie.", systemImage: "hand.raised")
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !store.lastRunOutput.isEmpty {
                    GlassPanel {
                        Text(store.lastRunOutput)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
