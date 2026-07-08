import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    private let accent = Color.nobsAccent

    private var groupedDevices: [(domain: String, devices: [HomeDevice])] {
        let grouped = Dictionary(grouping: model.homeDevices, by: \.domain)
        return grouped.keys.sorted().map { domain in
            (domain: domain, devices: grouped[domain]?.sorted { $0.name < $1.name } ?? [])
        }
    }

    var body: some View {
        List {
            platformsSection

            if !model.tankAvailable {
                Section {
                    Text("Home devices are read from Tank. Reconnect in Privacy to see your setup.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if model.isLoadingHomeDevices {
                Section {
                    HStack {
                        ProgressView().tint(accent)
                        Text("Loading devices from Tank…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let message = model.homeDevicesMessage, !model.homeDevicesConfigured {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Home Assistant not connected")
                            .font(.headline)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } else if model.homeDevices.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No devices found")
                            .font(.headline)
                        Text("When Home Assistant is configured on Tank, lights, switches, and other entities appear here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                ForEach(groupedDevices, id: \.domain) { group in
                    Section(group.devices.first?.domainTitle ?? group.domain.capitalized) {
                        ForEach(group.devices) { device in
                            deviceRow(device)
                        }
                    }
                }
                if model.homeDevicesTruncated {
                    Section {
                        Text("Showing the first 100 devices. Ask NOBS in chat for a filtered list.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("Device control stays approval-gated. Ask NOBS in chat to change a device — you'll review the action in Approvals before anything runs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .refreshable { await model.loadHomeDevices() }
        .task { await model.loadHomeDevices() }
    }

    private var platformsSection: some View {
        Section("Platforms") {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Home via Home Assistant")
                        .font(.subheadline.weight(.semibold))
                    Text(model.homeDevicesConfigured ? "Connected on Tank" : "Not configured on Tank")
                        .font(.caption)
                        .foregroundStyle(model.homeDevicesConfigured ? accent : .secondary)
                }
            } icon: {
                Image(systemName: "house.fill")
                    .foregroundStyle(accent)
            }

            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Home")
                        .font(.subheadline.weight(.semibold))
                    Text("Not connected yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.secondary)
            }

            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amazon Alexa")
                        .font(.subheadline.weight(.semibold))
                    Text("Not connected yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func deviceRow(_ device: HomeDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: device))
                .foregroundStyle(accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline.weight(.semibold))
                Text(device.entityId)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(device.state.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func iconName(for device: HomeDevice) -> String {
        switch device.domain {
        case "light": "lightbulb.fill"
        case "switch": "power"
        case "climate": "thermometer.medium"
        case "lock": "lock.fill"
        case "cover": "blinds.horizontal.closed"
        case "media_player": "hifispeaker.fill"
        case "sensor": "sensor.fill"
        default: "circle.fill"
        }
    }
}
