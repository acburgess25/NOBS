import SwiftUI

struct FamilyView: View {
    @State private var homeHub = HomeHub.macMini
    @State private var adultPrivacy = true
    @State private var teenEducation = true
    @State private var childMentalSafety = true
    @State private var parentApprovals = true
    @State private var messageApprovals = true
    @State private var likedMessageExecutes = true
    @State private var onboardingInterview = true
    @State private var callAnalysisRequiresApproval = true
    @State private var appleFamilySharing = true
    @State private var elderCareMode = true
    @State private var cloudKitRoleShares = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(
                    title: "Family",
                    subtitle: "Run a private home agent, map people to Apple-family roles, and share only what each person approves."
                )

                GlassPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker("Home hub", selection: $homeHub) {
                            ForEach(HomeHub.allCases) { hub in
                                Label(hub.title, systemImage: hub.symbolName)
                                    .tag(hub)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: homeHub.symbolName)
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(Color.nobsBlue)
                                .frame(width: 58, height: 58)
                                .background(Color.nobsBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                            VStack(alignment: .leading, spacing: 5) {
                                Text(homeHub.title)
                                    .font(.headline)
                                Text(homeHub.description)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                    FamilyRoleCard(
                        title: "Adult",
                        subtitle: "Private encrypted workspace. Other adults cannot read personal memory, chats, notes, or account history unless explicitly shared.",
                        symbolName: "person.crop.circle.badge.checkmark",
                        tint: .blue
                    )

                    FamilyRoleCard(
                        title: "Teen",
                        subtitle: "More independence with education guardrails, mental health escalation, parent-approved sensitive actions, and transparent activity boundaries.",
                        symbolName: "graduationcap",
                        tint: .sage
                    )

                    FamilyRoleCard(
                        title: "Kid",
                        subtitle: "Strict child-safe assistant mode with learning goals, blocked mature topics, no private external sharing, and parent-controlled contact rules.",
                        symbolName: "figure.2.and.child.holdinghands",
                        tint: .amber
                    )

                    FamilyRoleCard(
                        title: "Elder",
                        subtitle: "Supported account for elderly family members with consented caregiver access, safer reminders, call summaries, and escalation alerts.",
                        symbolName: "figure.walk.motion",
                        tint: .blue
                    )
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Apple Family integration")
                            .font(.headline)

                        Toggle(isOn: $appleFamilySharing) {
                            Label("Support Apple Family Sharing for eligible NOBS subscriptions and purchases", systemImage: "person.3.sequence")
                        }

                        Toggle(isOn: $cloudKitRoleShares) {
                            Label("Use CloudKit sharing for approved family records and role-based permissions", systemImage: "icloud.and.arrow.up")
                        }

                        Toggle(isOn: $elderCareMode) {
                            Label("Enable elder and caregiver account setup", systemImage: "heart.text.square")
                        }

                        Divider()

                        Label("Do not assume NOBS can create or manage the user's Apple Family group directly.", systemImage: "exclamationmark.shield")
                        Label("Use Apple's native sharing surfaces where possible: Family Sharing, CloudKit shares, App Intents, Shortcuts, Reminders, Calendar, and Contacts prompts.", systemImage: "apple.logo")
                        Label("Let an organizer invite family members into NOBS roles: admin, adult private member, teen, kid, elder, or caregiver.", systemImage: "person.badge.plus")
                        Label("For elders, require consent before caregiver-visible reminders, call summaries, location-like status, or health-adjacent notes.", systemImage: "hand.raised")
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Guardrails")
                            .font(.headline)

                        Toggle(isOn: $adultPrivacy) {
                            Label("Encrypt adult spaces from other adults", systemImage: "lock.shield")
                        }

                        Toggle(isOn: $teenEducation) {
                            Label("Enable teen education and productivity coaching", systemImage: "book.closed")
                        }

                        Toggle(isOn: $childMentalSafety) {
                            Label("Enable kid and teen mental safety boundaries", systemImage: "heart.text.square")
                        }

                        Toggle(isOn: $parentApprovals) {
                            Label("Require parent approval for purchases, external sharing, and account changes", systemImage: "person.badge.key")
                        }

                        Toggle(isOn: $messageApprovals) {
                            Label("Text a proposed course of action before meaningful changes", systemImage: "message.badge")
                        }

                        Toggle(isOn: $likedMessageExecutes) {
                            Label("Treat a reply, approval, or liked message as permission to run the plan", systemImage: "hand.thumbsup")
                        }
                    }
                    .toggleStyle(.switch)
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Family scaling model")
                            .font(.headline)

                        Label("One home hub can serve multiple phones on the local network.", systemImage: "house.and.flag")
                        Label("Away from home, phones can reach the hub through an encrypted relay when allowed.", systemImage: "network")
                        Label("If the internet is down, phone and hub should still coordinate locally where Bluetooth or LAN is available.", systemImage: "dot.radiowaves.left.and.right")
                        Label("Hosted Tank access stays optional, useful for beta testers or homes without always-available hardware.", systemImage: "server.rack")
                        Label("If a person needs more compute than parent hardware should run, offer their own Mac, Linux box, paid usage, or ask the family admin to install it.", systemImage: "person.crop.circle.badge.questionmark")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Approval flow")
                            .font(.headline)

                        Label("Learn each person's routines and preferences from approved activity.", systemImage: "brain.head.profile")
                        Label("Propose the fix by text or notification before taking action.", systemImage: "bubble.left.and.text.bubble.right")
                        Label("A reply, approval button, or liked message starts the approved plan.", systemImage: "checkmark.message")
                        Label("Big kid, teen, and adult actions route to the parent or admin account when required.", systemImage: "person.2.badge.gearshape")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("30-minute Apple life interview")
                            .font(.headline)

                        Toggle(isOn: $onboardingInterview) {
                            Label("Start a guided setup chat when Apple Intelligence, a server, Tank, or a subscription is available", systemImage: "person.wave.2")
                        }

                        Toggle(isOn: $callAnalysisRequiresApproval) {
                            Label("Analyze recorded calls only after explicit confirmation", systemImage: "phone.badge.waveform")
                        }

                        Divider()

                        Label("Ask how the person uses Calendar, Reminders, Notes, Messages, Mail, Files, Focus, Shortcuts, and calls.", systemImage: "questionmark.bubble")
                        Label("Recommend everyday Apple workflows based on the person's role and routine.", systemImage: "apple.logo")
                        Label("For students, request permission before managing class notes, assignments, reminders, or family-visible schedules.", systemImage: "graduationcap")
                        Label("For recorded calls, summarize and extract follow-ups only when the person grants access.", systemImage: "checkmark.shield")
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private enum HomeHub: String, CaseIterable, Identifiable {
    case macMini
    case linuxBox
    case tankBeta

    var id: String { rawValue }

    var title: String {
        switch self {
        case .macMini: "Mac mini"
        case .linuxBox: "Linux box"
        case .tankBeta: "Tank beta"
        }
    }

    var symbolName: String {
        switch self {
        case .macMini: "macmini"
        case .linuxBox: "terminal"
        case .tankBeta: "server.rack"
        }
    }

    var description: String {
        switch self {
        case .macMini:
            "Best Apple-native home base: local models, iCloud files, App Intents, Family Sharing-style setup, and easy phone relay."
        case .linuxBox:
            "Best always-on local compute base: efficient services, local network access, containerized agents, and low-cost expansion."
        case .tankBeta:
            "Best for beta testers without home hardware: hosted runtime on Tank while we learn real workload and pricing needs."
        }
    }
}

private struct FamilyRoleCard: View {
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
