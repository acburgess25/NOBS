import CoreImage.CIFilterBuiltins
import SwiftUI

struct MenuContentView: View {
    @Bindable var supervisor: TankSupervisor

    @State private var question = ""
    @State private var answer: String?
    @State private var answerRoute: String?
    @State private var errorText: String?
    @State private var isAsking = false
    @State private var showPairingSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            statusRows
            Divider()
            askSection
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
        .sheet(isPresented: $showPairingSheet) { pairingSheet }
        .task { await supervisor.refresh() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "shippingbox.fill")
            Text("NOBS Tank")
                .font(.headline)
            Spacer()
            Text("Mobile Tank")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            statusRow("Tank API", value: supervisor.serverStatus.label,
                      healthy: supervisor.serverStatus == .running)
            statusRow("Ollama", value: supervisor.ollamaRunning ? "Running" : "Stopped",
                      healthy: supervisor.ollamaRunning)
            statusRow("Local model", value: LocalAssistant.availabilityDescription,
                      healthy: LocalAssistant.isAvailable)
            if let ip = supervisor.lanAddress {
                statusRow("Network", value: ip, healthy: true)
            }
        }
    }

    private func statusRow(_ name: String, value: String, healthy: Bool) -> some View {
        HStack {
            Circle()
                .fill(healthy ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(name)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(value)")
    }

    private var askSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Ask NOBS…", text: $question)
                .textFieldStyle(.roundedBorder)
                .onSubmit { ask() }
                .disabled(isAsking)

            if isAsking {
                ProgressView()
                    .controlSize(.small)
            }
            if let answer {
                ScrollView {
                    Text(answer)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 160)
                if let answerRoute {
                    Label(answerRoute, systemImage: answerRoute == "Local"
                          ? "iphone.gen3" : "shippingbox")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Where this response was processed")
                }
            }
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Pair iPhone") { showPairingSheet = true }
                .disabled(supervisor.pairingURL == nil)
            Button("Restart Tank") { supervisor.restartServer() }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .controlSize(.small)
    }

    private var pairingSheet: some View {
        VStack(spacing: 12) {
            Text("Pair your iPhone")
                .font(.headline)
            Text("In NOBS on iPhone, choose Scan QR and point the camera here. The token stays on your devices.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let payload = supervisor.pairingURL, let image = qrImage(for: payload) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .accessibilityLabel("QR code for pairing with Tank")
            } else {
                Text("Pairing unavailable: no device token or network address.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button("Done") { showPairingSheet = false }
        }
        .padding(20)
        .frame(width: 300)
    }

    private func ask() {
        let message = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isAsking else { return }
        isAsking = true
        answer = nil
        answerRoute = nil
        errorText = nil

        Task {
            defer { isAsking = false }
            // Tank first when healthy; otherwise fall back to the on-device model.
            if supervisor.serverStatus == .running, let token = supervisor.deviceToken {
                do {
                    let reply = try await TankClient().chat(
                        baseURL: supervisor.serverURL, token: token, message: message)
                    answer = reply.message
                    answerRoute = reply.route
                    return
                } catch {
                    errorText = "Tank route failed, trying Local…"
                }
            }
            do {
                answer = try await LocalAssistant().respond(to: message)
                answerRoute = "Local"
                errorText = nil
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func qrImage(for payload: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let representation = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        return image
    }
}
