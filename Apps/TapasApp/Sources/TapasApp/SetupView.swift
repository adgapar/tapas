import SwiftUI
import TapasCore

@MainActor @Observable
final class SetupModel {
    var flow: SetupFlow
    var downloading = false
    var busy = false
    var practiceText = ""
    var phase: DictationPhase = .idle
    var completedPractice = false
    init(flow: SetupFlow) { self.flow = flow }
}

struct SetupView: View {
    @Bindable var model: SetupModel
    var onPrimary: () async -> Void
    var onSecondary: () -> Void
    var onSkip: () -> Void
    var onPractice: () async -> Void
    var onCancel: () -> Void
    var onHotkey: (Hotkey) -> Void

    private var step: Int {
        switch model.flow.phase {
        case .peek: 0; case .microphone: 1; case .accessibility: 2
        case .kitchen: 3; case .tryIt: 4; case .finished: 5
        }
    }
    private var heading: String {
        switch model.flow.phase {
        case .peek: "A small start."
        case .microphone: "Let’s hear"
        case .accessibility: "Say it here."
        case .kitchen: "A little prep."
        case .tryIt: "Go on."
        case .finished: "Now, back"
        }
    }
    private var accent: String {
        switch model.flow.phase {
        case .peek: "A good habit."
        case .microphone: "your thing."
        case .accessibility: "Write anywhere."
        case .kitchen: "Then we’re ready."
        case .tryIt: "Say a little."
        case .finished: "to your day."
        }
    }
    private var description: String {
        switch model.flow.phase {
        case .peek: "A few clever tools, right here on your Mac. First up: turn a thought into words."
        case .microphone: "Allow your microphone so Dictado can turn speech into text. It listens when you start a take."
        case .accessibility: "Accessibility enables your shortcut across apps and lets Tapas paste where your cursor is. You can also copy finished words yourself."
        case .kitchen: "Bring the voice models onto your Mac. After this one-time setup, Dictado works offline."
        case .tryIt: "Press once to start, again to finish. Try a real sentence—the words will appear here."
        case .finished: "Your next thought is one shortcut away. \(model.flow.hotkeyLabel) to start. The same to finish."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 25) {
                    Spacer()
                    PintxoMark(phase: model.phase.isActive ? model.phase : model.downloading ? .finishing : .idle,
                               pieces: step == 0 || step > 3 ? 4 : step)
                        .frame(width: 140, height: 235)
                    Text("SMALL TOOLS.\nGOOD COMPANY.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2)
                    Spacer()
                }
                .frame(width: 205).frame(maxHeight: .infinity).background(Grafico.saffron.opacity(0.86))
                Rectangle().fill(Grafico.ink).frame(width: 1)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: step == 0 ? "Your first taste of Tapas" : "0\(step) / \(model.flow.phase == .finished ? "Ready with gusto" : "A first taste")")
                        VStack(alignment: .leading, spacing: 0) {
                            Text(heading).font(.system(size: 32, weight: .bold)).tracking(-1.2)
                            Text(accent).font(.system(size: 34, design: .serif)).italic().foregroundStyle(Grafico.olive)
                        }
                        Text(description).font(.system(size: 13)).foregroundStyle(Grafico.muted).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                        content
                        if let error = model.flow.modelError { NoticeBox(text: error, error: true) }
                        actions
                    }
                    .padding(30)
                }
            }
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<6) { i in Capsule().fill(i == step ? Grafico.olive : Grafico.olive.opacity(0.25)).frame(width: i == step ? 20 : 5, height: 5) }
                }.accessibilityLabel("Step \(step + 1) of 6")
                Spacer()
                Eyebrow(text: "Local intelligence. With gusto.")
            }.padding(20).background(Grafico.paper)
        }
        .foregroundStyle(Grafico.ink).background(Grafico.card).preferredColorScheme(.light)
        .frame(width: 680, height: 560)
    }

    @ViewBuilder private var content: some View {
        switch model.flow.phase {
        case .peek:
            HStack(spacing: 14) {
                ToolGlyph(symbol: "waveform")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dictado").font(.system(size: 14, weight: .semibold))
                    Text("You say it. It lands where you type.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
                }
            }.padding(.vertical, 8)
        case .microphone:
            NoticeBox(text: model.flow.microphoneGranted ? "✓ Microphone is allowed." : "Used during your takes. Audio stays on this Mac.")
        case .accessibility:
            NoticeBox(text: model.flow.accessibilityTrusted ? (model.flow.tapStarted ? "✓ Shortcut and paste access are ready." : "Access is allowed. Reopen Tapas if the global shortcut is still unavailable.") : "System Settings → Privacy & Security → Accessibility → Tapas")
        case .kitchen:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(model.flow.modelsReady ? "Ready on this Mac" : model.flow.downloadFraction >= 0.9 ? "Preparing the models…" : "Downloading voice models…")
                    Spacer()
                    Text(model.flow.downloadFraction, format: .percent.precision(.fractionLength(0)))
                }.font(.system(size: 11, design: .monospaced))
                ProgressView(value: model.flow.downloadFraction).tint(Grafico.olive)
                Text("A one-time download. You can leave this window open while it prepares.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            }
        case .tryIt:
            HStack {
                Text("Your shortcut").font(.system(size: 12))
                Spacer()
                Menu(model.flow.hotkeyLabel) {
                    Button("Control–Option") { onHotkey(.standard) }
                    Button("Right Command") { onHotkey(.rightCommand) }
                }.fixedSize().disabled(model.phase.isActive)
            }
            ScrollView {
                Text(model.practiceText.isEmpty ? (model.phase == .listening ? "Listening…" : "A little more room for the good ideas.") : model.practiceText)
                    .font(.system(size: 15)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).padding(12)
            }.frame(height: 72).background(Grafico.paper, in: RoundedRectangle(cornerRadius: 7))
            HStack {
                Button(model.phase == .listening ? "Finish the thought" : model.phase == .finishing ? "Finishing…" : "Try a take") { Task { await onPractice() } }
                    .buttonStyle(GraficoButtonStyle()).disabled(model.busy || model.phase == .finishing)
                if model.phase == .listening { Button("Cancel", action: onCancel).buttonStyle(.plain) }
            }
        case .finished:
            NoticeBox(text: "Your words have a home.\nDocuments / tapas / dictado\nPlain files for you and the tools you use.")
        }
    }

    @ViewBuilder private var actions: some View {
        if model.flow.phase == .accessibility && !model.flow.accessibilityTrusted {
            Button("Enable in Settings ↗", action: onSecondary).buttonStyle(GraficoButtonStyle(blue: true))
            Button("Later. I’ll copy my words.") { Task { await onPrimary() } }.buttonStyle(.plain).font(.system(size: 12))
        } else {
            Button(primaryTitle) { Task { await onPrimary() } }
                .buttonStyle(GraficoButtonStyle(blue: model.flow.phase == .finished))
                .disabled(model.busy || model.downloading || (model.flow.phase == .tryIt && (!model.completedPractice || model.phase.isActive)))
        }
        if model.flow.phase != .finished {
            Button("Set up later", action: onSkip).buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Grafico.muted)
        }
        if model.flow.phase == .peek { Text("No account. Voice processing stays on this Mac.").font(.system(size: 10)).foregroundStyle(Grafico.muted) }
    }

    private var primaryTitle: String {
        switch model.flow.phase {
        case .peek: "Let’s make a start →"
        case .microphone: model.flow.microphoneGranted ? "Continue →" : "Allow microphone →"
        case .accessibility: "Continue →"
        case .kitchen: model.flow.modelsReady ? "Give it a try →" : model.downloading ? "Getting ready…" : "Prepare voice models →"
        case .tryIt: "That’s the idea. Continue →"
        case .finished: "Back to my day →"
        }
    }
}
