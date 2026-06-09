import SwiftUI

struct IntegrationsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    IntegrationRow(icon: "apple.intelligence", name: "Apple Intelligence", status: "On-device AI — iOS 26+", configured: true)
                    IntegrationRow(icon: "heart.fill", name: "Apple Health (HealthKit)", status: "Active — syncing macros & vitals", configured: true)
                    IntegrationRow(icon: "eye.fill", name: "Screen Time API", status: "Monitoring 20-20-20 eye rest breaks", configured: true)
                    IntegrationRow(icon: "homekit", name: "HomeKit", status: "Entitlement set — ready on device", configured: true)
                    IntegrationRow(icon: "message", name: "iMessage Compose", status: "Opens Messages app", configured: true)
                    IntegrationRow(icon: "calendar", name: "Calendar", status: "EventKit — list wellness events", configured: true)
                    IntegrationRow(icon: "mic", name: "Siri AI & Shortcuts", status: "App Intents — ask via Siri AI", configured: true)
                } header: {
                    Text("Available via Chat").sectionOverline()
                }
                .listRowBackground(Color.nobsCard)

                Section {
                    IntegrationRow(icon: "faceid", name: "Face ID", status: "App launch & background lock", configured: true)
                    IntegrationRow(icon: "heart.text.square.fill", name: "Health Logs", status: "On-device symptoms & diet stores", configured: true)
                    IntegrationRow(icon: "bell", name: "Wellness Reminders", status: "EventKit integration", configured: true)
                    IntegrationRow(icon: "checklist", name: "Meds Schedule", status: "On-device dose tracking", configured: true)
                } header: {
                    Text("Active").sectionOverline()
                }
                .listRowBackground(Color.nobsCard)

                Section {
                    IntegrationRow(icon: "cpu", name: "AI Model", status: "Apple Intelligence / Tank fallback", configured: true)
                    IntegrationRow(icon: "cloud", name: "API Server", status: "nobsdash.com (Cloudflare tunnel)", configured: true)
                } header: {
                    Text("Server").sectionOverline()
                }
                .listRowBackground(Color.nobsCard)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.nobsBg)
            .navigationTitle("Integrations")
        }
    }
}

struct IntegrationRow: View {
    let icon: String
    let name: String
    let status: String
    let configured: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: configured ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(configured ? Color.nobsGreen : Color.nobsSecondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(NOBSFont.body())
                    .foregroundStyle(Color.nobsPrimary)
                Text(status)
                    .font(NOBSFont.caption())
                    .foregroundStyle(Color.nobsSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}
