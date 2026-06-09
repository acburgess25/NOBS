import SwiftUI

struct TankAIView: View {
    @Environment(CommandCenterStore.self) private var store
    @AppStorage("tankAIPrimaryName") private var primaryName = "Alex"
    @AppStorage("tankAIPartnerName") private var partnerName = "Boyfriend"
    @AppStorage("tankAISharedMemoryEnabled") private var sharedMemoryEnabled = true
    @AppStorage("tankAIPrivateProfilesEnabled") private var privateProfilesEnabled = true
    @AppStorage("tankAIAskBeforeSharing") private var askBeforeSharing = true
    @AppStorage("tankAIAutoOffline") private var autoOffline = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(
                    title: "Tank AI",
                    subtitle: "Personal AI for you two, with private profiles, shared plans, and fast online/offline routing."
                )

                GlassPanel {
                    HStack(alignment: .top, spacing: 18) {
                        Image(systemName: "person.2.wave.2")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color.nobsBlue)
                            .frame(width: 62, height: 62)
                            .background(Color.nobsBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Tank AI")
                                .font(.title2.weight(.bold))

                            HStack(spacing: 12) {
                                TextField("You", text: $primaryName)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Partner", text: $partnerName)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    store.selectedSection = .chat
                                } label: {
                                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    store.runtimeMode = .auto
                                    Task { await store.refreshRuntimeStatus() }
                                } label: {
                                    Label("Auto", systemImage: "arrow.triangle.branch")
                                }

                                Button {
                                    store.runtimeMode = .offline
                                } label: {
                                    Label("Offline", systemImage: "wifi.slash")
                                }

                                Button {
                                    Task { await store.approveMorningDocument() }
                                } label: {
                                    Label("Approve Morning Doc", systemImage: "checkmark.seal.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(store.isWorking)
                            }

                            if store.morningDocumentApproved {
                                Label("Approved and generated locally for 8 AM.", systemImage: "checkmark.circle.fill")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Color.nobsSage)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                    TankAICard(
                        title: "\(primaryName)'s space",
                        subtitle: "Private memory, routines, reminders, notes, and chat history stay yours unless you share them.",
                        symbolName: "person.crop.circle.badge.checkmark",
                        tint: .blue
                    )

                    TankAICard(
                        title: "\(partnerName)'s space",
                        subtitle: "Separate preferences and context, with the same consent rules and local-first routing.",
                        symbolName: "person.crop.circle.badge.moon",
                        tint: .sage
                    )

                    TankAICard(
                        title: "Shared space",
                        subtitle: "Plans, household tasks, trips, decisions, and recurring routines both people approve.",
                        symbolName: "heart.text.square",
                        tint: .amber
                    )
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy rules")
                            .font(.headline)

                        Toggle(isOn: $privateProfilesEnabled) {
                            Label("Keep personal profiles separate by default", systemImage: "lock.shield")
                        }

                        Toggle(isOn: $sharedMemoryEnabled) {
                            Label("Enable a shared Tank AI memory space", systemImage: "person.2.badge.gearshape")
                        }

                        Toggle(isOn: $askBeforeSharing) {
                            Label("Ask before moving anything from private memory into shared memory", systemImage: "hand.raised")
                        }

                        Toggle(isOn: $autoOffline) {
                            Label("Switch offline fast when Tank or the internet is unavailable", systemImage: "bolt.horizontal")
                        }
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Runtime")
                            .font(.headline)

                        Label(store.runtimeStatusText, systemImage: store.activeRoute.symbolName)
                        Label("Online uses Tank at nobsdash.com when available.", systemImage: "server.rack")
                        Label("Offline uses the local model helper on this Mac.", systemImage: "macbook")
                        Label("Auto checks quickly before each chat and falls back without making you manage it.", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TankAICard: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: NOBSTint

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbolName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint.color)
                    .frame(width: 42, height: 42)
                    .background(tint.color.opacity(0.12), in: Circle())

                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
