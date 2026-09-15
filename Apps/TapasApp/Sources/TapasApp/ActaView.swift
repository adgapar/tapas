import AppKit
import SwiftUI
import TapasCore

struct ActaView: View {
    @Bindable var model: ActaModel
    let controller: ActaController

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Eyebrow(text: "A little room for the conversation")
                    Text("Acta").font(.system(size: 34, weight: .bold)).tracking(-1)
                    Text("Be there. Keep the conversation.").font(.system(size: 14, design: .serif)).italic()
                }
                Spacer()
                PintxoMark(phase: model.snapshot.phase == .recording ? .listening : .idle).frame(width: 48, height: 68)
            }.padding(26)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let error = model.error { NoticeBox(text: error, error: true) }
                    if let message = model.snapshot.message { NoticeBox(text: message, error: model.snapshot.phase == .recovery) }
                    if model.snapshot.phase == .idle { preflight }
                    else { meeting }
                }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.frame(width: 540, height: 650).background(Grafico.card).foregroundStyle(Grafico.ink).preferredColorScheme(.light)
    }

    private var preflight: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Record your microphone and one app on this Mac. Choose your browser for a web meeting; audio from its other tabs may also be captured.").font(.system(size: 13)).lineSpacing(4)
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
            Text("Meeting app").font(.system(size: 13, weight: .medium))
            if !model.apps.isEmpty {
                Picker("Meeting app", selection: $model.selectedApp) {
                    ForEach(model.apps) { app in Text(app.name).tag(Optional(app.id)) }
                }.labelsHidden().frame(maxWidth: .infinity)
            }
            Button(model.apps.isEmpty ? "Allow app audio & load apps" : "Refresh apps") { Task { await controller.loadApps() } }.disabled(model.busy)
            Text("macOS may request Screen & System Audio Recording access. Acta keeps audio only.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            Button { Task { await controller.start() } } label: {
                HStack { Text(model.busy ? "Preparing…" : "Start Acta"); Spacer(); Image(systemName: "arrow.right") }
            }.buttonStyle(GraficoButtonStyle()).disabled(model.busy || !model.ready || !model.microphoneGranted || model.selectedApp == nil)
            Text("Start when everyone is ready to be recorded.\nFull transcripts are saved locally in Documents/tapas/acta. Temporary recovery audio is removed after a successful save.")
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
                Text("Closing this window keeps the meeting companion visible. Recorded time excludes pauses.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
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
        HStack(spacing: 14) {
            PintxoMark(phase: model.snapshot.phase == .recording ? .listening : .idle).frame(width: 42, height: 65)
            VStack(alignment: .leading, spacing: 8) {
                Text("Acta · \(ActaDocument.timestamp(model.elapsed))").font(.system(size: 13, weight: .semibold, design: .monospaced))
                Text(model.status).font(.system(size: 10)).lineLimit(1)
                if model.snapshot.phase == .recording {
                    Text("Mic: \(model.microphoneSeen ? "connected" : "waiting") · App: \(model.appSeen ? "connected" : "waiting")")
                        .font(.system(size: 9)).foregroundStyle(Grafico.muted)
                }
                HStack(spacing: 14) {
                    Button("Open ↗", action: controller.show)
                    if model.snapshot.phase == .recording { Button("Pause") { Task { await controller.pause() } } }
                    else if model.canResume { Button("Resume") { Task { await controller.resume() } } }
                    if [.recording, .paused, .recovery].contains(model.snapshot.phase) { Button("Finish") { Task { await controller.finish() } } }
                }.font(.system(size: 11)).buttonStyle(.plain).disabled(model.busy)
            }
            Spacer(minLength: 0)
        }.padding(16).frame(width: 330, height: 116).background(Grafico.paper, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(Grafico.ink).preferredColorScheme(.light)
    }
}
