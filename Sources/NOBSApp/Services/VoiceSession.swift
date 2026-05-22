import Foundation
import CryptoKit
import AVFoundation

@MainActor
class VoiceSession: ObservableObject {
    @Published var isConnected = false
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var transcribedText = ""
    @Published var statusMessage = ""

    private var webSocket: URLSessionWebSocketTask?
    private var sessionKey: SymmetricKey?
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL

    private let wsURL = URL(string: "wss://nobsdash.com/ws/voice")!

    init() {
        let dir = FileManager.default.temporaryDirectory
        recordingURL = dir.appendingPathComponent("voice_input.wav")
    }

    func connect() {
        let session = URLSession(configuration: .ephemeral)
        webSocket = session.webSocketTask(with: wsURL)
        webSocket?.resume()
        listen()

        let key = SymmetricKey(size: .bits256)
        sessionKey = key
        let hex = key.withUnsafeBytes { Data($0).map { String(format: "%02x", $0) }.joined() }
        let msg = ["type": "key_exchange", "key": hex]
        if let data = try? JSONSerialization.data(withJSONObject: msg) {
            webSocket?.send(.data(data)) { _ in }
        }
        isConnected = true
    }

    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        sessionKey = nil
        isConnected = false
        isProcessing = false
        isRecording = false
    }

    func startRecording() {
        guard isConnected else {
            statusMessage = "Kitchen not connected"
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default)
        try? audioSession.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]

        guard let recorder = try? AVAudioRecorder(url: recordingURL, settings: settings) else {
            statusMessage = "Mic not ready"
            return
        }
        recorder.record()
        audioRecorder = recorder
        isRecording = true
        statusMessage = "Listening..."
    }

    func stopRecordingAndSend(context: String = "") {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        guard isConnected, let key = sessionKey else {
            isProcessing = false
            return
        }
        isProcessing = true
        statusMessage = "Sealing your order..."

        guard let wavData = try? Data(contentsOf: recordingURL) else {
            statusMessage = "Nothing recorded"
            isProcessing = false
            return
        }

        do {
            let sealed = try AES.GCM.seal(wavData, using: key)
            guard let combined = sealed.combined else {
                statusMessage = "Couldn't seal container"
                isProcessing = false
                return
            }
            let b64 = combined.base64EncodedString()
            var payload: [String: Any] = ["type": "voice", "data": b64]
            if !context.isEmpty { payload["context"] = context }

            let msgData = try JSONSerialization.data(withJSONObject: payload)
            webSocket?.send(.data(msgData)) { [weak self] error in
                if error != nil {
                    DispatchQueue.main.async {
                        self?.statusMessage = "Delivery failed"
                        self?.isProcessing = false
                    }
                }
            }
        } catch {
            statusMessage = "Couldn't seal container"
            isProcessing = false
        }
    }

    private func listen() {
        webSocket?.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                case .failure:
                    self.isConnected = false
                    self.statusMessage = "Disconnected"
                }
                if self.isConnected { self.listen() }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            guard let text = String(data: data, encoding: .utf8) else { return }
            handleText(text)
        case .string(let text):
            handleText(text)
        @unknown default:
            break
        }
    }

    private func handleText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        switch msg["type"] as? String {
        case "key_ack":
            statusMessage = "Secure line to kitchen open"

        case "status":
            let detail = msg["detail"] as? String ?? ""
            switch detail {
            case "transcribing": statusMessage = "Chef is writing down your order..."
            case "thinking": statusMessage = "Chef is preparing the meal..."
            case "synthesizing": statusMessage = "Plating your order..."
            default: statusMessage = detail
            }
            if let t = msg["text"] as? String { transcribedText = t }

        case "response":
            guard let audioB64 = msg["audio"] as? String,
                  let encrypted = Data(base64Encoded: audioB64),
                  let key = sessionKey,
                  let sealed = try? AES.GCM.SealedBox(combined: encrypted)
            else {
                statusMessage = "Order was garbled"
                isProcessing = false
                return
            }
            do {
                let wavData = try AES.GCM.open(sealed, using: key)
                playAudio(wavData)
                statusMessage = "Meal is served"
            } catch {
                statusMessage = "Couldn't open the container"
            }
            isProcessing = false

        case "error":
            let detail = msg["detail"] as? String ?? ""
            switch detail {
            case "no_speech": statusMessage = "Chef didn't hear anything"
            case "decrypt_failed": statusMessage = "Container seal was tampered"
            default: statusMessage = "Kitchen error: \(detail)"
            }
            isProcessing = false

        default:
            break
        }
    }

    private func playAudio(_ wavData: Data) {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let player = try? AVAudioPlayer(data: wavData) else {
            statusMessage = "Playback failed"
            return
        }
        audioPlayer = player
        player.play()
    }
}
