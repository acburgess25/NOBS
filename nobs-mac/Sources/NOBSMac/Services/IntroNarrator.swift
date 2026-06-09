import AVFoundation
import Combine
import Foundation

@MainActor
final class IntroNarrator: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var selectedVoiceIdentifier: String
    @Published var voiceName = "System Voice"

    private let synthesizer = AVSpeechSynthesizer()
    let availableVoices: [AVSpeechSynthesisVoice]

    static let preferredVoiceNames = [
        "Flo",
        "Shelley",
        "Sandy",
        "Samantha",
        "Moira",
        "Karen",
        "Daniel"
    ]

    init(selectedVoiceIdentifier: String? = nil) {
        let voices = Self.goodEnglishVoices()
        self.availableVoices = voices
        self.selectedVoiceIdentifier = selectedVoiceIdentifier
            ?? Self.preferredVoice(from: voices)?.identifier
            ?? AVSpeechSynthesisVoice(language: "en-US")?.identifier
            ?? ""
        super.init()
        synthesizer.delegate = self
        updateVoiceName()
    }

    func speak(_ text: String) {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice()
        utterance.rate = 0.42
        utterance.pitchMultiplier = 0.98
        utterance.volume = 0.95
        utterance.preUtteranceDelay = 0.08
        utterance.postUtteranceDelay = 0.16
        utterance.prefersAssistiveTechnologySettings = true

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func setVoice(identifier: String) {
        selectedVoiceIdentifier = identifier
        updateVoiceName()
        stop()
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    private func selectedVoice() -> AVSpeechSynthesisVoice? {
        availableVoices.first { $0.identifier == selectedVoiceIdentifier }
            ?? Self.preferredVoice(from: availableVoices)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    private func updateVoiceName() {
        voiceName = selectedVoice()?.name ?? "System Voice"
    }

    private static func preferredVoice(from voices: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
        for name in preferredVoiceNames {
            if let voice = voices.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame && $0.language == "en-US" }) {
                return voice
            }
        }

        for name in preferredVoiceNames {
            if let voice = voices.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                return voice
            }
        }

        return voices.first
    }

    private static func goodEnglishVoices() -> [AVSpeechSynthesisVoice] {
        let blocked = [
            "Albert", "Bad News", "Bahh", "Bells", "Boing", "Bubbles", "Cellos",
            "Wobble", "Fred", "Good News", "Jester", "Junior", "Kathy", "Organ",
            "Superstar", "Ralph", "Trinoids", "Whisper", "Zarvox", "Grandma", "Grandpa"
        ]

        return AVSpeechSynthesisVoice.speechVoices()
            .filter { voice in
                voice.language.hasPrefix("en")
                    && !blocked.contains(where: { voice.name.localizedCaseInsensitiveContains($0) })
            }
            .sorted { lhs, rhs in
                let lhsRank = preferredVoiceNames.firstIndex(where: { lhs.name.localizedCaseInsensitiveCompare($0) == .orderedSame }) ?? 99
                let rhsRank = preferredVoiceNames.firstIndex(where: { rhs.name.localizedCaseInsensitiveCompare($0) == .orderedSame }) ?? 99

                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }

                if lhs.language != rhs.language {
                    return lhs.language == "en-US"
                }

                return lhs.name < rhs.name
            }
    }
}
