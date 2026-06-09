import SwiftUI

struct AppleIntegrationView: View {
    private let capabilities = [
        ("App Intents", "Expose NOBS health actions to Shortcuts, Spotlight, and Siri AI surfaces.", "app.badge"),
        ("HealthKit Sync", "Seamlessly read Apple Health vitals, macro targets, and sleep metrics.", "heart.fill"),
        ("Meds & Reminders", "Track medication dosing times, daily eye strain breaks, and health goals.", "checklist"),
        ("iCloud Health Folder", "Sync offline clinical logs and encrypted meal plans via iCloud.", "note.text"),
        ("Bluetooth Local", "Keep phone and Mac useful together when the network is gone.", "dot.radiowaves.left.and.right")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(
                    title: "Apple",
                    subtitle: "Native Apple app capabilities first: App Intents, Shortcuts, iCloud files, and privacy-preserving local workflows."
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                    ForEach(capabilities, id: \.0) { item in
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: item.2)
                                    .font(.title2)
                                    .foregroundStyle(Color.nobsBlue)

                                Text(item.0)
                                    .font(.headline)

                                Text(item.1)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
