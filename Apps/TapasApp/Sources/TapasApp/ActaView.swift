import AppKit
import SwiftUI
import TapasCore

/// Acta inside the home card (Sobremesa).
struct ActaView: View {
    @Bindable var model: ActaModel
    let controller: ActaController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                SkewerPintxo(form: model.snapshot.phase == .recording ? .standing(split: true) : model.snapshot.phase == .finishing ? .working : .resting,
                             level: speech(model.microphoneLevel), others: speech(model.appLevel))
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Acta").font(Sobremesa.display(34, weight: 600))
                    Text(model.status).font(.system(size: 13, weight: .semibold)).foregroundStyle(Sobremesa.muted)
                }
            }
            if let error = model.error { Notice(text: error, error: true) }
            if let message = model.snapshot.message { Notice(text: message, error: model.snapshot.phase == .recovery) }
            if model.snapshot.phase == .saved {
                if model.showingSavedReceipt { savedReceipt }
                else {
                    savedActions
                    preflight
                }
            } else if model.snapshot.phase == .idle { preflight } else { meeting }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func speech(_ level: Double) -> CGFloat { min(1, CGFloat(sqrt(max(0, level))) * 2.5) }

    private var savedActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            DoneMark(text: "Last meeting kept · \(ActaDocument.timestamp(model.snapshot.document?.duration ?? 0))")
            HStack(spacing: 12) {
                Button("View transcript ↗", action: controller.openSavedTranscript)
                    .buttonStyle(.printed(.secondary, small: true)).disabled(model.snapshot.savedURL == nil)
                Button("Export Markdown…", action: controller.export)
                    .buttonStyle(.printed(.quiet, small: true)).disabled(model.busy)
            }
        }
    }

    private var savedReceipt: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Conversation kept.").font(Sobremesa.display(26, weight: 600))
            Text("Your transcript is saved on this Mac. Find it in What you kept.")
                .font(.system(size: 13)).foregroundStyle(Sobremesa.muted)
            Button("New meeting", action: controller.show).buttonStyle(.printed(.primary)).disabled(model.busy)
            savedActions
        }
    }

    private func source(_ title: String, detail: String, granted: Bool, allow: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Sobremesa.display(18, weight: 600))
                Text(detail).font(.system(size: 12.5)).foregroundStyle(Sobremesa.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if granted { DoneMark(text: "Allowed") }
            else { Button(allow, action: action).buttonStyle(.printed(.secondary, small: true)).disabled(model.busy) }
        }.padding(.vertical, 10)
    }

    private var preflight: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("You stand up on the left, everyone else on the right. Nothing records until you say so.")
                .font(Sobremesa.display(18)).fixedSize(horizontal: false, vertical: true)
            if !model.ready {
                Notice(text: "Prepare the speech model in Setup before your first meeting.")
                Button("Open Setup", action: controller.onSetup).buttonStyle(.printed(.primary, small: true))
            }
            VStack(spacing: 0) {
                source("Your microphone", detail: "Captures you.", granted: model.microphoneGranted, allow: "Allow") {
                    Task { await controller.allowMicrophone() }
                }
                Rectangle().fill(Sobremesa.ink.opacity(0.14)).frame(height: 1)
                source("Computer audio", detail: "Captures the other side, and sounds from other apps. No screen images are saved.",
                       granted: model.appAudioGranted, allow: "Allow") { Task { await controller.allowAppAudio() } }
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            .printed(CutShape(tight: 4, round: 18))
            Button { Task { await controller.start() } } label: {
                HStack { Text(model.busy ? "Preparing…" : "Keep this conversation"); Spacer(); Image(systemName: "arrow.right") }
            }
            .buttonStyle(.printed(.primary))
            .disabled(model.busy || !model.ready || !model.microphoneGranted || !model.appAudioGranted)
            Text("Start when everyone is ready to be recorded. Temporary recovery audio is removed after a successful save.")
                .font(.system(size: 12)).foregroundStyle(Sobremesa.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var meeting: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(ActaDocument.timestamp(model.elapsed)).font(Sobremesa.display(40, weight: 600)).monospacedDigit()
                .foregroundStyle(model.snapshot.phase == .paused ? Sobremesa.muted : Sobremesa.ink)
            if model.snapshot.phase == .recording || model.snapshot.phase == .paused {
                HStack(spacing: 18) {
                    inputState("You", seen: model.microphoneSeen, level: model.microphoneLevel, color: Sobremesa.cobalt)
                    inputState("Others", seen: model.appSeen, level: model.appLevel, color: Sobremesa.paprika)
                }
                HStack(spacing: 12) {
                    if model.snapshot.phase == .recording {
                        Button("Pause") { Task { await controller.pause() } }.buttonStyle(.printed(.secondary))
                    } else if model.canResume {
                        Button("Resume") { Task { await controller.resume() } }.buttonStyle(.printed(.secondary))
                    }
                    Button("Finish & keep") { Task { await controller.finish() } }.buttonStyle(.printed(.primary))
                }.disabled(model.busy)
            }
            if model.snapshot.phase == .finishing {
                Text("Finishing your transcript on this Mac…").font(.system(size: 13, weight: .semibold))
            }
            if model.snapshot.phase == .recovery {
                Button("Retry transcription & save") { Task { await controller.finish() } }.buttonStyle(.printed(.primary)).disabled(model.busy)
            }
            if [.recovery, .paused].contains(model.snapshot.phase) {
                HStack(spacing: 12) {
                    Button(model.snapshot.pendingChunks > 0 ? "Export available text…" : "Export Markdown…", action: controller.export)
                        .buttonStyle(.printed(.secondary, small: true))
                    Button("Discard meeting…") { Task { await controller.discard() } }
                        .buttonStyle(.printed(.quiet, small: true))
                }.disabled(model.busy)
            }
            GroupLabel(text: "Words so far").padding(.top, 6)
            if model.snapshot.pendingChunks > 0 {
                Text("\(model.snapshot.pendingChunks) audio chunks waiting for recognition.").font(.system(size: 12)).foregroundStyle(Sobremesa.muted)
            }
            let segments = model.snapshot.document?.segments.sorted { $0.start < $1.start } ?? []
            if segments.isEmpty {
                Text("Words appear as audio is transcribed on this Mac.").font(.system(size: 13)).foregroundStyle(Sobremesa.muted)
            }
            // A bounded preview keeps long meetings responsive; the file retains every segment.
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(segments.suffix(30).enumerated()), id: \.offset) { _, segment in
                    let mine = segment.source == .microphone
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(ActaDocument.timestamp(segment.start)) · \(mine ? "You" : "Others")")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(mine ? Sobremesa.cobalt : Sobremesa.paprika)
                        Text(segment.text).font(Sobremesa.display(15)).textSelection(.enabled)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text("“You” is your microphone and “Others” is computer audio, not individual speakers. Headphones keep voices from appearing in both.")
                .font(.system(size: 12)).foregroundStyle(Sobremesa.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func inputState(_ title: String, seen: Bool, level: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            CutShape(tight: 2, round: 4).fill(color).frame(width: 9, height: 14)
                .overlay(CutShape(tight: 2, round: 4).inkBorder(Sobremesa.ink, lineWidth: 1.2))
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(model.snapshot.phase == .paused ? "paused" : !seen ? "waiting for audio" : level > 0.015 ? "talking" : "quiet")
                .font(.system(size: 13)).foregroundStyle(Sobremesa.muted)
        }
    }
}

/// The floating companion while a call is kept: the split pintxo and a printed pill.
/// The pill never changes size; paused sits the pieces down and greys the time.
struct ActaCompanion: View {
    @Bindable var model: ActaModel
    let controller: ActaController

    private func speech(_ level: Double) -> CGFloat { min(1, CGFloat(sqrt(max(0, level))) * 2.5) }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if model.companionNeedsDetails {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(model.snapshot.phase == .saved ? "Kept." : model.status).font(Sobremesa.display(18, weight: 600))
                        Spacer()
                        if model.snapshot.phase == .saved {
                            Button(action: controller.dismissReceipt) { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)) }
                                .buttonStyle(.plain).accessibilityLabel("Dismiss saved receipt")
                        }
                    }
                    if let message = model.error ?? model.snapshot.message {
                        Text(message).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    }
                    Button(model.snapshot.phase == .saved ? "View transcript ↗" : "Open Acta ↗") {
                        if model.snapshot.phase == .saved { controller.openSavedTranscript() } else { controller.show() }
                    }.buttonStyle(.printed(.secondary, small: true))
                }
                .padding(16)
                .printed(CutShape(tight: 4, round: 20), offset: CGSize(width: 3, height: 4))
                .padding(.trailing, 4)
            }
            if model.hasSession {
                VStack(spacing: 6) {
                    Button(action: toggleCapture) {
                        SkewerPintxo(form: model.snapshot.phase == .recording ? .standing(split: true) : model.snapshot.phase == .finishing ? .working : .resting,
                                     level: speech(model.microphoneLevel), others: speech(model.appLevel))
                            .frame(width: 104, height: 104)
                            .opacity(model.snapshot.phase == .paused ? 0.55 : 1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(!canToggleCapture)
                    .accessibilityLabel(model.snapshot.phase == .recording ? "Pause Acta recording" : "Resume Acta recording")
                    pill
                }
            }
        }
        .padding(10)
        .frame(width: model.companionSize.width, height: model.companionSize.height, alignment: .bottomTrailing)
        .foregroundStyle(Sobremesa.ink).preferredColorScheme(.light)
    }

    private var pill: some View {
        let paused = model.snapshot.phase != .recording
        return HStack(spacing: 0) {
            Button(action: toggleCapture) {
                Image(systemName: paused ? "play.fill" : "pause.fill").font(.system(size: 11))
                    .frame(width: 30, height: 30)
                    .background(CutShape(tight: 3, round: 11).fill(Sobremesa.paperShade))
                    .overlay(CutShape(tight: 3, round: 11).inkBorder(Sobremesa.ink, lineWidth: 1.3))
            }
            .buttonStyle(.plain).disabled(!canToggleCapture)
            .accessibilityLabel(paused ? "Resume recording" : "Pause recording")
            Spacer(minLength: 0)
            Button(action: controller.show) {
                Text(ActaDocument.timestamp(model.elapsed)).font(Sobremesa.display(16, weight: 600)).monospacedDigit()
                    .foregroundStyle(paused ? Sobremesa.muted : Sobremesa.ink)
            }
            .buttonStyle(.plain).accessibilityLabel("Open Acta details")
            Spacer(minLength: 0)
            Button { Task { await controller.finish() } } label: {
                Image(systemName: "stop.fill").font(.system(size: 11)).foregroundStyle(Sobremesa.paprika)
                    .frame(width: 30, height: 30)
                    .background(CutShape(tight: 3, round: 11).fill(Sobremesa.paperShade))
                    .overlay(CutShape(tight: 3, round: 11).inkBorder(Sobremesa.ink, lineWidth: 1.3))
            }
            .buttonStyle(.plain).disabled(model.busy || model.snapshot.phase == .finishing)
            .accessibilityLabel("Finish and keep meeting")
        }
        .padding(.horizontal, 6)
        .frame(width: 156, height: 42)
        .printed(CutShape(tight: 5, round: 18), offset: CGSize(width: 3, height: 4))
        .padding(.trailing, 3)
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
