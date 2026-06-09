import SwiftUI

struct NOBSIntroView: View {
    let autoplay: Bool
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var narrator = IntroNarrator()
    @AppStorage("introNarratorVoiceIdentifier") private var savedVoiceIdentifier = ""
    @State private var selectedIndex = 0
    @State private var isAutoPlaying = false
    @State private var glow = false

    private let scenes = IntroScene.nobsIntro

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                NOBSBrandLockup()

                Spacer()

                Button {
                    finish()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(22)

            Divider()

            HStack(spacing: 0) {
                cinematicStage
                    .frame(minWidth: 460)

                Divider()

                lessonPanel
                    .frame(width: 360)
            }
            .frame(minHeight: 520)
        }
        .frame(minWidth: 860, minHeight: 620)
        .background(.regularMaterial)
        .task {
            guard autoplay else { return }
            try? await Task.sleep(for: .milliseconds(450))
            await playAll()
        }
        .onDisappear {
            narrator.stop()
        }
    }

    private var cinematicStage: some View {
        ZStack {
            Color.clear

            SignalNetworkView()
                .scaleEffect(1.45)
                .opacity(0.48)
                .blur(radius: 0.2)

            VStack(spacing: 22) {
                NOBSLogoMark(size: 112)
                    .scaleEffect(glow ? 1.04 : 0.98)

                VStack(spacing: 8) {
                    Text(currentScene.title)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(currentScene.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GlassPanel(padding: 14, radius: 20) {
                    HStack(spacing: 14) {
                        Image(systemName: currentScene.symbolName)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(currentScene.tint.color)
                            .frame(width: 44, height: 44)
                            .background(currentScene.tint.color.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Teaching now")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(currentScene.title)
                                .font(.headline)
                        }

                        Spacer()

                        PermissionWave()
                            .opacity(narrator.isSpeaking ? 1 : 0.45)
                    }
                }
                .frame(maxWidth: 460)
            }
            .padding(34)
        }
        .animation(.smooth(duration: 0.5), value: selectedIndex)
        .animation(.smooth(duration: 2.2).repeatForever(autoreverses: true), value: glow)
        .onAppear { glow = true }
    }

    private var lessonPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Intro Video")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("A guided walkthrough with native Mac narration. Use this to teach a new family member what NOBS does before asking for permissions.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    speakCurrent()
                } label: {
                    Label(narrator.isSpeaking ? "Replay" : "Play", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    narrator.stop()
                    isAutoPlaying = false
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!narrator.isSpeaking && !isAutoPlaying)
            }

            Text("Voice: \(narrator.voiceName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Narrator", selection: $savedVoiceIdentifier) {
                ForEach(narrator.availableVoices, id: \.identifier) { voice in
                    Text("\(voice.name) · \(voice.language)")
                        .tag(voice.identifier)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: savedVoiceIdentifier) { _, newValue in
                narrator.setVoice(identifier: newValue)
            }
            .onAppear {
                if savedVoiceIdentifier.isEmpty {
                    savedVoiceIdentifier = narrator.selectedVoiceIdentifier
                } else {
                    narrator.setVoice(identifier: savedVoiceIdentifier)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(scenes.enumerated()), id: \.element.id) { index, scene in
                    Button {
                        selectedIndex = index
                        speakCurrent()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: scene.symbolName)
                                .foregroundStyle(scene.tint.color)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(scene.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(scene.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            if selectedIndex == index {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.nobsSage)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .background(selectedIndex == index ? Color.primary.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Spacer()

            Button {
                Task { await playAll() }
            } label: {
                Label("Play Full Intro", systemImage: "sparkles.tv")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
    }

    private var currentScene: IntroScene {
        scenes[selectedIndex]
    }

    private func speakCurrent() {
        narrator.speak(currentScene.narration)
    }

    @MainActor
    private func playAll() async {
        isAutoPlaying = true

        for index in scenes.indices {
            guard isAutoPlaying else { break }
            selectedIndex = index
            narrator.speak(scenes[index].narration)
            try? await Task.sleep(for: .seconds(7))
        }

        isAutoPlaying = false
    }

    private func finish() {
        narrator.stop()
        onDone()
        dismiss()
    }
}
