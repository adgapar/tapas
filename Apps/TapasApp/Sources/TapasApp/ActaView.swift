import AppKit
import SwiftUI
import TapasCore

struct ActaView: View {
    @Bindable var model: ActaModel
    let controller: ActaController

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { ToolGlyph(symbol: "text.bubble", color: Grafico.cobalt); Spacer(); Eyebrow(text: "Meeting notes") }
            Text("Acta").font(.system(size: 30, weight: .bold)).tracking(-1)
            Text("Be there. Keep the conversation.").font(.system(size: 13, design: .serif)).italic()
            if let error = model.error { NoticeBox(text: error, error: true) }
            if let message = model.snapshot.message { NoticeBox(text: message, error: model.snapshot.phase == .recovery) }
            if model.snapshot.phase == .saved {
                if model.showingSavedReceipt { savedReceipt }
                else {
                    savedActions
                    Divider()
                    preflight
                }
            } else if model.snapshot.phase == .idle { preflight } else { meeting }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var savedActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Last meeting saved · \(ActaDocument.timestamp(model.snapshot.document?.duration ?? 0))", systemImage: "checkmark.circle")
                .font(.system(size: 12)).foregroundStyle(Grafico.olive)
            HStack(spacing: 12) {
                Button("View transcript ↗", action: controller.openSavedTranscript)
                    .buttonStyle(GraficoButtonStyle(secondary: true, compact: true))
                    .disabled(model.snapshot.savedURL == nil)
                Button("Export Markdown…", action: controller.export)
                    .buttonStyle(GraficoButtonStyle(secondary: true, compact: true)).disabled(model.busy)
            }
        }
    }

    private var savedReceipt: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Conversation kept.").font(.system(size: 24, weight: .semibold))
            Text("Your transcript is saved. Find it anytime in Recent.")
                .font(.system(size: 13)).foregroundStyle(Grafico.muted)
            Button("New meeting", action: controller.show)
                .buttonStyle(GraficoButtonStyle()).disabled(model.busy)
            savedActions
        }
    }

    private var preflight: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your microphone captures you. Computer audio captures the other voices.").font(.system(size: 13)).lineSpacing(4)
            if !model.ready {
                NoticeBox(text: "Prepare the voice models in Setup before your first meeting.")
                Button("Open Setup", action: controller.onSetup).buttonStyle(GraficoButtonStyle())
            }
            HStack {
                Text("Your microphone").font(.system(size: 13, weight: .medium))
                Spacer()
                if model.microphoneGranted { Label("Allowed", systemImage: "checkmark.circle").foregroundStyle(Grafico.olive) }
                else { Button("Allow microphone") { Task { await controller.allowMicrophone() } } }
            }.font(.system(size: 12))
            Divider()
            HStack {
                Text("Computer audio").font(.system(size: 13, weight: .medium))
                Spacer()
                if model.appAudioGranted {
                    Label("Allowed", systemImage: "checkmark.circle").foregroundStyle(Grafico.olive)
                } else {
                    Button("Allow computer audio") { Task { await controller.allowAppAudio() } }
                        .buttonStyle(GraficoButtonStyle(secondary: true, compact: true)).disabled(model.busy)
                }
            }.font(.system(size: 12))
            if !model.appAudioGranted {
                Text("Allow Screen & System Audio Recording in macOS. Acta captures audio only.")
                    .font(.system(size: 11)).foregroundStyle(Grafico.muted)
            }
            Text("Includes sound from other apps and notifications. No screen images are saved.")
                .font(.system(size: 11)).foregroundStyle(Grafico.muted)
            Button { Task { await controller.start() } } label: {
                HStack { Text(model.busy ? "Preparing…" : "Start Acta"); Spacer(); Image(systemName: "arrow.right") }
            }.buttonStyle(GraficoButtonStyle()).disabled(model.busy || !model.ready || !model.microphoneGranted || !model.appAudioGranted)
            Text("Start when everyone is ready to be recorded.\nTranscripts use your shared folder in Preferences. Temporary recovery audio is removed after a successful save.")
                .font(.system(size: 11)).foregroundStyle(Grafico.muted).lineSpacing(4)
        }
    }

    private var meeting: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(ActaDocument.timestamp(model.elapsed)).font(.system(size: 34, weight: .medium, design: .monospaced))
                    Text(model.status).font(.system(size: 12, weight: .medium))
                }
                Spacer()
                ToolGlyph(symbol: "text.bubble", color: Grafico.cobalt)
            }
            if model.snapshot.phase == .recording || model.snapshot.phase == .paused {
                meter("Your microphone", value: model.microphoneLevel, seen: model.microphoneSeen)
                meter("Computer audio", value: model.appLevel, seen: model.appSeen)
                HStack {
                    if model.snapshot.phase == .recording {
                        Button("Pause") { Task { await controller.pause() } }.buttonStyle(GraficoButtonStyle(secondary: true))
                    } else if model.canResume {
                        Button("Resume") { Task { await controller.resume() } }.buttonStyle(GraficoButtonStyle(secondary: true))
                    }
                    Button("Finish & save") { Task { await controller.finish() } }.buttonStyle(GraficoButtonStyle())
                }.disabled(model.busy)
                Text("You can return to All tools while recording. A floating companion stays visible when you leave Acta. Recorded time excludes pauses.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            }
            if model.snapshot.phase == .finishing {
                ProgressView().controlSize(.small)
                Text("Finishing recognition and saving your local file…").font(.system(size: 12))
            }
            if model.snapshot.phase == .recovery {
                Button("Retry transcription & save") { Task { await controller.finish() } }.buttonStyle(GraficoButtonStyle()).disabled(model.busy)
            }
            if [.recovery, .paused].contains(model.snapshot.phase) {
                HStack(spacing: 12) {
                    Button(model.snapshot.pendingChunks > 0 ? "Export available text…" : "Export Markdown…", action: controller.export)
                        .buttonStyle(GraficoButtonStyle(secondary: true, compact: true))
                    Button("Discard meeting…") { Task { await controller.discard() } }
                        .buttonStyle(GraficoButtonStyle(secondary: true, compact: true))
                }.disabled(model.busy)
            }
            Divider()
            Eyebrow(text: "Words so far")
            if model.snapshot.pendingChunks > 0 {
                Text("\(model.snapshot.pendingChunks) audio chunks waiting for recognition.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            }
            let segments = model.snapshot.document?.segments.sorted { $0.start < $1.start } ?? []
            if segments.isEmpty {
                Text("Words appear as audio is transcribed on this Mac.").font(.system(size: 13)).foregroundStyle(Grafico.muted)
            }
            // A bounded preview keeps long meetings responsive; the file retains every segment.
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(segments.suffix(30).enumerated()), id: \.offset) { _, segment in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(ActaDocument.timestamp(segment.start)) · \(segment.source.label)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Grafico.muted)
                            Text(segment.text).font(.system(size: 13)).lineSpacing(4).textSelection(.enabled)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 230)
            Text("Source labels identify microphone or computer audio, not individual speakers. Headphones help prevent voices appearing in both inputs.").font(.system(size: 11)).foregroundStyle(Grafico.muted)

        }
    }

    private func meter(_ label: String, value: Double, seen: Bool) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Text(model.snapshot.phase == .paused ? "Paused" : !seen ? "Waiting for audio" : value > 0.015 ? "Audio detected" : "Quiet")
                    .foregroundStyle(Grafico.muted)
            }.font(.system(size: 11))
            ProgressView(value: model.snapshot.phase == .recording ? value : 0).tint(Grafico.cobalt)
        }
    }
}

struct ActaCompanion: View {
    @Bindable var model: ActaModel
    let controller: ActaController

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if model.companionNeedsDetails {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(model.status).font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if model.snapshot.phase == .saved {
                            ClosePlateButton(label: "Dismiss saved receipt", action: controller.dismissReceipt)
                        }
                    }
                    if let message = model.error ?? model.snapshot.message {
                        Text(message).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    }
                    Button(model.snapshot.phase == .saved ? "View transcript ↗" : "Open Acta ↗") {
                        if model.snapshot.phase == .saved { controller.openSavedTranscript() }
                        else { controller.show() }
                    }
                        .font(.system(size: 11)).buttonStyle(.plain)
                }.plateSurface()
            }
            if model.hasSession {
                VStack(spacing: 8) {
                    Button(action: toggleCapture) {
                        ActaPintxoSignal(history: model.waveform, recording: model.snapshot.phase == .recording)
                            .frame(width: 92, height: 112)
                            .overlay(alignment: .bottomTrailing) {
                                if model.snapshot.phase == .paused {
                                    Image(systemName: "pause.fill").font(.system(size: 9))
                                        .padding(4).background(Grafico.card, in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(!canToggleCapture)
                    .accessibilityLabel(model.snapshot.phase == .recording ? "Pause Acta recording" : "Resume Acta recording")
                    HStack(spacing: 8) {
                        Button(action: toggleCapture) {
                            Image(systemName: model.snapshot.phase == .recording ? "pause.fill" : "play.fill")
                                .frame(width: 26, height: 26)
                        }
                        .disabled(!canToggleCapture)
                        .accessibilityLabel(model.snapshot.phase == .recording ? "Pause recording" : "Resume recording")
                        .help(model.snapshot.phase == .recording ? "Pause recording" : "Resume recording")
                        Button(action: controller.show) {
                            Text(ActaDocument.timestamp(model.elapsed)).font(.system(size: 10, design: .monospaced))
                        }.accessibilityLabel("Open Acta details")
                        Button { Task { await controller.finish() } } label: {
                            Image(systemName: "stop.fill").frame(width: 26, height: 26)
                        }.disabled(model.busy || model.snapshot.phase == .finishing)
                            .accessibilityLabel("Finish and save meeting").help("Finish and save")
                    }
                    .buttonStyle(.plain).font(.system(size: 11))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Grafico.card, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Grafico.ink, lineWidth: 1))
                    .shadow(color: Grafico.ink.opacity(0.35), radius: 0, x: 2, y: 3)
                }
            }
        }
        .padding(10)
        .frame(width: model.companionSize.width, height: model.companionSize.height, alignment: .bottomTrailing)
        .foregroundStyle(Grafico.ink).preferredColorScheme(.light)
    }
    private var canToggleCapture: Bool {
        !model.busy && (model.snapshot.phase == .recording || model.canResume)
    }

    private func toggleCapture() {
        Task {
            if model.snapshot.phase == .recording { await controller.pause() }
            else { await controller.resume() }
        }
    }
}

/// A quiet Pintxo unfolds into eight independently measured bars during speech.
struct ActaPintxoSignal: View {
    let history: ActaWaveformHistory
    let recording: Bool
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    private var appeared = SwiftUI.State<Bool>(initialValue: false)

    var body: some View {
        let speaking = appeared.wrappedValue && recording && history.hasRecentAudio
        ActaPintxoDrawing(morph: speaking ? 1 : 0, history: history, reducedMotion: reducedMotion)
            .animation(reducedMotion ? nil : .easeInOut(duration: 0.65), value: speaking)
            .onAppear { appeared.wrappedValue = true }
            .accessibilityHidden(true)
    }
}

/// Interpolating one drawing preserves the identity of the four ingredients
/// as each splits into two bars, and reverses smoothly without swapping views.
struct ActaPintxoDrawing: View, Animatable {
    nonisolated var morph: CGFloat
    let history: ActaWaveformHistory
    let reducedMotion: Bool
    nonisolated var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let mix = min(1, max(0, morph))
            let colors = [Grafico.saffron, Grafico.cobalt, Grafico.paprika, Grafico.olive]
            let scale = min(size.width / 130, size.height / 160)
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
            context.rotate(by: .degrees(PintxoArtwork.tilt * (1 - mix)))
            var pick = Path()
            pick.move(to: CGPoint(x: 0, y: -72)); pick.addLine(to: CGPoint(x: 0, y: 72))
            context.stroke(pick, with: .color(Grafico.ink.opacity(1 - mix)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round))
            for index in 0..<8 {
                let ingredient = index / 2
                let level = history.levels[reducedMotion ? 23 : 23 - index * 2]
                let envelope = 0.65 + 0.35 * sin(.pi * (Double(index) + 0.5) / 8)
                let barHeight = 6 + sqrt(level) * 76 * envelope
                let height = 24 * (1 - mix) + barHeight * mix
                let width = PintxoArtwork.widths[ingredient] * (1 - mix) + 8 * mix
                let x = (CGFloat(index) - 3.5) * 12 * mix
                let y = (CGFloat(ingredient) * 29 - 42) * (1 - mix)
                let radius = PintxoArtwork.corner(ingredient) * (1 - mix) + 4 * mix
                let rect = CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
                let opacity = index.isMultiple(of: 2) ? 1 : min(1, mix * 2)
                context.opacity = opacity * (1 - 0.65 * mix)
                context.fill(Path(roundedRect: rect.offsetBy(dx: 2 - mix, dy: 3 - mix), cornerRadius: radius), with: .color(Grafico.ink))
                context.opacity = opacity
                let path = Path(roundedRect: rect, cornerRadius: radius)
                context.fill(path, with: .color(colors[ingredient]))
                context.stroke(path, with: .color(Grafico.ink), lineWidth: 1.8 - mix)
            }
        }
    }
}
