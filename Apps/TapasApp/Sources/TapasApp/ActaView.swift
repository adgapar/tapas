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
            if model.snapshot.phase == .idle { preflight } else { meeting }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var preflight: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your microphone captures you. Choose where the other voices come from—for example, Zoom or the browser running your meeting.").font(.system(size: 13)).lineSpacing(4)
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
            Text("Where is your meeting?").font(.system(size: 13, weight: .medium))
            if !model.apps.isEmpty {
                Picker("Meeting audio source", selection: $model.selectedApp) {
                    Text("Choose an app…").tag(Optional<Int32>.none)
                    ForEach(model.apps) { app in Text(app.name).tag(Optional(app.id)) }
                }.labelsHidden().frame(maxWidth: .infinity)
            }
            if model.appAudioGranted {
                Label("App audio allowed", systemImage: "checkmark.circle").font(.system(size: 12)).foregroundStyle(Grafico.olive)
                Button("Refresh apps") { Task { await controller.loadApps() } }.disabled(model.busy)
            } else {
                Text("Allow meeting audio to see available apps.").font(.system(size: 12))
                Button("Allow meeting audio") { Task { await controller.allowAppAudio() } }.buttonStyle(GraficoButtonStyle(secondary: true)).disabled(model.busy)
                Button("Open System Settings", action: controller.openAppAudioSettings).buttonStyle(.plain)
            }
            Text("macOS calls this Screen & System Audio Recording. Acta records audio only; it does not save screen images. If you choose a browser, other tabs’ audio may be included.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            Button { Task { await controller.start() } } label: {
                HStack { Text(model.busy ? "Preparing…" : "Start Acta"); Spacer(); Image(systemName: "arrow.right") }
            }.buttonStyle(GraficoButtonStyle()).disabled(model.busy || !model.ready || !model.microphoneGranted || !model.appAudioGranted || model.selectedApp == nil)
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
                meter(model.snapshot.document?.appName ?? "App audio", value: model.appLevel, seen: model.appSeen)
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
            if let url = model.snapshot.savedURL {
                Button("Open transcript ↗") { NSWorkspace.shared.open(url) }.buttonStyle(GraficoButtonStyle())
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }.buttonStyle(.plain)
            }
            Divider()
            Eyebrow(text: model.snapshot.phase == .saved ? "Your transcript" : "Words so far")
            if model.snapshot.pendingChunks > 0 {
                Text("\(model.snapshot.pendingChunks) audio chunks waiting for recognition.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            }
            let segments = model.snapshot.document?.segments.sorted { $0.start < $1.start } ?? []
            if segments.isEmpty {
                Text(model.snapshot.phase == .saved ? "No speech was recognized." : "Words appear as audio is transcribed on this Mac.").font(.system(size: 13)).foregroundStyle(Grafico.muted)
            }
            // A bounded preview keeps long meetings responsive; the file retains every segment.
            ForEach(Array(segments.suffix(30).enumerated()), id: \.offset) { _, segment in
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(ActaDocument.timestamp(segment.start)) · \(segment.source == .microphone ? "Microphone" : "App audio")").font(.system(size: 10, design: .monospaced)).foregroundStyle(Grafico.muted)
                    Text(segment.text).font(.system(size: 13)).lineSpacing(4).textSelection(.enabled)
                }
            }
            Text("Source labels identify microphone or app audio, not individual speakers. Headphones help prevent voices appearing in both inputs.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            if [.saved, .recovery, .paused].contains(model.snapshot.phase) {
                Button(model.snapshot.pendingChunks > 0 ? "Export available text…" : "Export Markdown…", action: controller.export).disabled(model.busy)
            }
            if [.paused, .recovery].contains(model.snapshot.phase) {
                Button("Discard meeting…") { Task { await controller.discard() } }.disabled(model.busy)
            }
            if model.snapshot.phase == .saved {
                Button("New meeting") { Task { await controller.newMeeting() } }.disabled(model.busy)
            }
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
            Spacer(minLength: 0)
            if model.companionExpanded || model.snapshot.phase == .recovery || model.error != nil || model.snapshot.message != nil {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TapasWordmark(size: 23)
                        Spacer()
                        if model.snapshot.phase == .saved { ClosePlateButton(label: "Dismiss saved receipt", action: controller.dismissReceipt) }
                    }
                    Text(model.status).font(.system(size: 14, weight: .semibold))
                    if let message = model.error ?? model.snapshot.message {
                        Text(message).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 15) {
                        Button(model.snapshot.phase == .saved ? "View transcript ↗" : "Open Acta ↗", action: controller.show)
                        if model.snapshot.phase == .recording { Button("Pause") { Task { await controller.pause() } } }
                        else if model.canResume { Button("Resume") { Task { await controller.resume() } } }
                        if [.recording, .paused, .recovery].contains(model.snapshot.phase) { Button("Finish") { Task { await controller.finish() } } }
                    }.font(.system(size: 11)).buttonStyle(.plain).disabled(model.busy)
                }.plateSurface()
            }
            Button { model.companionExpanded.toggle() } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(model.snapshot.phase == .recording ? "Recording" : model.status).font(.system(size: 11, weight: .medium))
                        Text(ActaDocument.timestamp(model.elapsed)).font(.system(size: 12, design: .monospaced))
                    }.padding(10).background(Grafico.card, in: Capsule())
                    PintxoWaveform(recording: model.snapshot.phase == .recording, level: max(model.microphoneLevel, model.appLevel))
                }
            }.buttonStyle(.plain).accessibilityLabel("Acta, \(model.status). Toggle recording controls.")
        }.padding(10).frame(width: 340, height: 320).foregroundStyle(Grafico.ink).preferredColorScheme(.light)
    }
}
