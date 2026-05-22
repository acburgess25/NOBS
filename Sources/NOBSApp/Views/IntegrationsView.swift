import SwiftUI

struct IntegrationsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Available via Chat") {
                    FeatureRow(
                        icon: "homekit",
                        name: "HomeKit",
                        status: "Entitlement set — ready on device",
                        configured: true
                    )
                    FeatureRow(
                        icon: "phone",
                        name: "CallKit",
                        status: "Entitlement set — ready on device",
                        configured: true
                    )
                    FeatureRow(
                        icon: "message",
                        name: "iMessage",
                        status: "In-app compose → opens Messages app",
                        configured: true
                    )
                    FeatureRow(
                        icon: "phone",
                        name: "Phone Dialer",
                        status: "Uses tel:// URL scheme",
                        configured: true
                    )
                }

                Section("Active") {
                    FeatureRow(
                        icon: "faceid",
                        name: "Face ID",
                        status: "App launch & background lock",
                        configured: true
                    )
                    FeatureRow(
                        icon: "brain",
                        name: "Memories",
                        status: "On-device personal & work stores",
                        configured: true
                    )
                    FeatureRow(
                        icon: "bell",
                        name: "Reminders",
                        status: "EventKit integration",
                        configured: true
                    )
                    FeatureRow(
                        icon: "checklist",
                        name: "Tasks",
                        status: "On-device task management",
                        configured: true
                    )
                }

                Section("Server") {
                    FeatureRow(
                        icon: "server.rack",
                        name: "AI Model",
                        status: "qwen2:1.5b on tank (192.168.0.77)",
                        configured: true
                    )
                    FeatureRow(
                        icon: "cloud",
                        name: "API Server",
                        status: "nobsdash.com (Cloudflare tunnel)",
                        configured: true
                    )
                }
            }
            .navigationTitle("Integrations")
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let name: String
    let status: String
    let configured: Bool

    var body: some View {
        HStack {
            Image(systemName: configured ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(configured ? .green : .gray)
            VStack(alignment: .leading) {
                Text(name)
                    .font(.body)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
