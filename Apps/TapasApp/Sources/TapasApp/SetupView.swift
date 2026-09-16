import SwiftUI
import TapasCore

@MainActor @Observable
final class SetupModel {
    var flow: SetupFlow
    var stage = 0
    var downloading = false
    var busy = false
    var practiceText = ""
    var phase: DictationPhase = .idle
    var level: Double = 0
    var completedPractice = false
    var accessibilityChecked = false
    var appAudioGranted = false
    var transcriptDirectory = TapasSettings().transcriptDirectory
    var folderConfirmed = false
    var folderError: String?
    init(flow: SetupFlow) {
        self.flow = flow
        switch flow.phase {
        case .peek: stage = 0
        case .microphone, .accessibility: stage = 1
        case .kitchen: stage = 2
        case .tryIt, .finished: stage = 3
        }
    }
}

struct SetupView: View {
    @Bindable var model: SetupModel
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var onPrimary: () async -> Void
    var onSecondary: () -> Void
    var onSkip: () -> Void
    var onPractice: () async -> Void
    var onCancel: () -> Void
    var onHotkey: (Hotkey) -> Void
    var onRecheckAccessibility: () -> Void = {}
    var onRevealApplication: () -> Void = {}
    var onBack: () -> Void = {}
    var onMicrophone: () async -> Void = {}
    var onAppAudio: () async -> Void = {}
    var onChooseFolder: () -> Void = {}
    var onDefaultFolder: () -> Void = {}
    var onPrepare: () async -> Void = {}

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                TapasWordmark(size: 42).floatingLabel()
                Spacer()
                Text("Make yourself at home.").font(.system(size: 12)).foregroundStyle(Grafico.muted).floatingLabel()
                ClosePlateButton(label: "Close welcome", action: onSkip)
            }
            HStack(alignment: .center, spacing: 35) {
                illustration.frame(width: 340).id(model.stage)
                    .transition(reducedMotion ? .opacity : .opacity.combined(with: .offset(x: -12, y: 0)))
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        content
                        if let error = model.flow.modelError { NoticeBox(text: error, error: true) }
                    }.frame(maxWidth: .infinity, alignment: .leading).plateSurface()
                        .padding(.trailing, 6).padding(.bottom, 8)
                }.frame(maxWidth: .infinity, maxHeight: 465)
            }.frame(maxHeight: .infinity).animation(reducedMotion ? nil : .easeInOut(duration: 0.35), value: model.stage)
            IngredientProgress(step: model.stage).padding(.horizontal, 30).floatingLabel().padding(.horizontal, 60)
            HStack {
                if model.stage > 0 { Button("← Back", action: onBack).disabled(model.phase.isActive || model.busy) }
                else { Text("A few small steps. All on your Mac.").foregroundStyle(Grafico.muted) }
                Spacer()
                Button("Finish later", action: onSkip)
            }.font(.system(size: 11)).buttonStyle(.plain).floatingLabel()
        }.padding(26).frame(width: 920, height: 730).foregroundStyle(Grafico.ink).preferredColorScheme(.light)
    }

    private var illustration: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill([Grafico.saffron, Grafico.cobalt, Grafico.olive, Grafico.paprika][model.stage].opacity(0.14)).frame(width: 240, height: 240)
                if model.stage == 2 {
                    VStack(spacing: 0) {
                        HStack { Text("dictado.md"); Text("acta.md") }.font(.system(size: 11, design: .monospaced))
                            .padding(14).background(Grafico.card).rotationEffect(.degrees(-6))
                        Image(systemName: "folder.fill").font(.system(size: 130)).foregroundStyle(Grafico.saffron)
                    }
                } else {
                    PintxoWaveform(recording: model.phase == .listening, level: model.level).scaleEffect(model.stage == 1 ? 1.1 : 1.8)
                    if model.stage == 1 {
                        VStack {
                            accessBadge("Your voice", granted: model.flow.microphoneGranted).frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                            accessBadge("Your shortcuts", granted: model.flow.accessibilityTrusted).frame(maxWidth: .infinity, alignment: .trailing)
                            Spacer()
                            accessBadge("Meeting audio", granted: model.appAudioGranted).frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(14)
                    }
                }
            }.frame(height: 230)
            VStack(spacing: 12) {
            Text(["A place for\nyour thoughts.", "Just what\nyou need.", "Your words.\nYour place.", "Ready when\nyou are."][model.stage])
                .font(.system(size: 36, design: .serif)).italic().multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text(["Tapas are small dishes, better together. These tools share the same idea.", "A little access, with a clear purpose. You stay in control.", "Readable files in a folder you choose. Ready for whatever comes next.", "Pintxo keeps you company. The four ingredients become your voice."][model.stage])
                .font(.system(size: 12)).foregroundStyle(Grafico.muted).lineSpacing(5).multilineTextAlignment(.center).frame(maxWidth: 270).fixedSize(horizontal: false, vertical: true)
            }.floatingLabel()
        }
    }

    private func accessBadge(_ text: String, granted: Bool) -> some View {
        Label(text, systemImage: granted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 11)).padding(9).background(granted ? Grafico.olive.opacity(0.2) : Grafico.card, in: Capsule())
            .overlay(Capsule().stroke(Grafico.ink.opacity(0.7), lineWidth: 1))
    }

    @ViewBuilder private var content: some View {
        switch model.stage {
        case 0:
            Eyebrow(text: "Welcome to your table")
            Text("Small tools.\nGood company.").font(.system(size: 31, weight: .bold)).tracking(-1)
            Text("A thought to write. A conversation to keep. Make a little room for both.").font(.system(size: 13)).foregroundStyle(Grafico.muted)
            setupTool("Dictado", description: "Speak a thought. Put it where you’re writing.", symbol: "waveform", color: Grafico.saffron)
            setupTool("Acta", description: "Stay in the meeting. Keep the conversation.", symbol: "text.bubble", color: Grafico.cobalt)
            Text("Speech is processed on your Mac. Transcripts are your files, in a folder you choose.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            primary("Make yourself at home →")
        case 1:
            heading("A little access.")
            Text("Each permission has a purpose. You choose when to allow it.").font(.system(size: 13)).foregroundStyle(Grafico.muted)
            permission("Microphone", detail: "Your voice, for Dictado and Acta.", granted: model.flow.microphoneGranted) { Task { await onMicrophone() } }
            permission("Shortcuts & paste", detail: "Accessibility: both shortcuts + Dictado paste.", granted: model.flow.accessibilityTrusted, action: onSecondary)
            permission("Meeting audio · Acta", detail: "Screen & System Audio Recording.", granted: model.appAudioGranted) { Task { await onAppAudio() } }
            Text("Acta keeps audio transcripts, not screen images. Accessibility isn’t needed to record using buttons. You can enable meeting audio now or on your first meeting.")
                .font(.system(size: 11)).foregroundStyle(Grafico.muted).lineSpacing(4)
            if model.accessibilityChecked && !model.flow.accessibilityTrusted {
                NoticeBox(text: "Enable this copy of Tapas in System Settings → Privacy & Security → Accessibility, then check again.")
                Button("Show Tapas in Finder", action: onRevealApplication).buttonStyle(.plain)
            }
            Button("Check permissions again", action: onRecheckAccessibility).buttonStyle(.plain).font(.system(size: 11))
            primary("Continue →")
        case 2:
            heading("A home for your words.")
            Text("One shared folder for Dictado and Acta. Change it in Preferences anytime.").font(.system(size: 13)).foregroundStyle(Grafico.muted)
            HStack {
                Image(systemName: "folder").font(.system(size: 26)).foregroundStyle(Grafico.cobalt)
                Text(model.transcriptDirectory.path).font(.system(size: 11)).textSelection(.enabled)
                Spacer()
                Button("Choose…", action: onChooseFolder)
            }.padding(14).background(Grafico.paper, in: RoundedRectangle(cornerRadius: 9))
            Label("dictado · saved takes", systemImage: "folder").font(.system(size: 12))
            Label("acta · meeting transcripts", systemImage: "folder").font(.system(size: 12))
            Text("Tapas creates these subfolders for you. Existing files stay where they are.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            if let error = model.folderError { NoticeBox(text: error, error: true) }
            if model.folderConfirmed { NoticeBox(text: "Folder selected. Both tools use this location.") }
            else { Button("Use Documents/tapas", action: onDefaultFolder).buttonStyle(GraficoButtonStyle(secondary: true)) }
            primary("Continue →", disabled: !model.folderConfirmed)
        default:
            Eyebrow(text: "Try a little before you go")
            heading("Your first taste.")
            if !model.flow.modelsReady {
                Text("Prepare your local voice models once. Practice stays in this window.").font(.system(size: 13)).foregroundStyle(Grafico.muted)
                if model.downloading {
                    ProgressView(value: model.flow.downloadFraction).tint(Grafico.olive)
                    Text(model.flow.downloadFraction, format: .percent.precision(.fractionLength(0))).font(.system(size: 11, design: .monospaced))
                }
                Button(model.downloading ? "Preparing…" : "Prepare voice models") { Task { await onPrepare() } }.buttonStyle(GraficoButtonStyle()).disabled(model.downloading)
            } else if !model.flow.microphoneGranted {
                permission("Microphone", detail: "Allow it to try your first take.", granted: false) { Task { await onMicrophone() } }
            } else {
                Text("✓ Voice models ready on this Mac").font(.system(size: 11)).foregroundStyle(Grafico.olive)
                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(text: model.phase == .listening ? "Listening" : model.completedPractice ? "Your words, ready" : "Say something like")
                    Text(model.practiceText.isEmpty ? "Leave a little room for the good ideas." : model.practiceText)
                        .font(.system(size: 18, design: .serif)).italic().textSelection(.enabled)
                    Button(model.phase == .listening ? "Finish practice take" : model.phase == .finishing ? "Finishing…" : "Try a practice take") { Task { await onPractice() } }
                        .buttonStyle(GraficoButtonStyle(secondary: true)).disabled(model.busy || model.phase == .finishing || model.phase == .starting)
                    if model.phase == .listening { Button("Cancel practice", action: onCancel).buttonStyle(.plain) }
                    Text("Nothing is pasted or saved during practice.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
                }.padding(16).background(Grafico.paper, in: RoundedRectangle(cornerRadius: 10))
            }
            primary(model.completedPractice ? "Lovely. Let’s begin →" : "Open Tapas →", disabled: model.phase.isActive)
            Text("Acta suggests recording when another app uses your microphone. Recording is always your choice.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
        }
    }

    private func heading(_ title: String) -> some View { Text(title).font(.system(size: 29, weight: .bold)).tracking(-0.8) }
    private func primary(_ title: String, disabled: Bool = false) -> some View {
        Button { Task { await onPrimary() } } label: { HStack { Text(title); Spacer() } }
            .buttonStyle(GraficoButtonStyle()).disabled(disabled || model.busy)
    }
    private func permission(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 13)); Text(detail).font(.system(size: 10)).foregroundStyle(Grafico.muted) }
            Spacer()
            if granted { Image(systemName: "checkmark.circle.fill").foregroundStyle(Grafico.olive).accessibilityLabel("Allowed") }
            else { Button("Allow →", action: action).buttonStyle(.plain).foregroundStyle(Grafico.cobalt).disabled(model.busy) }
        }.padding(.vertical, 10)
    }
    private func setupTool(_ name: String, description: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ToolGlyph(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 5) { Text(name).font(.system(size: 16, weight: .semibold)); Text(description).font(.system(size: 11)).foregroundStyle(Grafico.muted) }
        }.padding(.vertical, 8)
    }
}
