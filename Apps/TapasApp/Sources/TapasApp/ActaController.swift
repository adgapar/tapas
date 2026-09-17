import AppKit
import AVFoundation
import CoreGraphics
import SwiftUI
import TapasCore

@MainActor @Observable
final class ActaModel {
    var snapshot = ActaSnapshot()
    var busy = false
    var ready = false
    var microphoneGranted = false
    var appAudioGranted = false
    var error: String?
    var elapsed: Double = 0
    var microphoneLevel: Double = 0
    var appLevel: Double = 0
    var microphoneSeen = false
    var appSeen = false
    var canResume = false
    var outputDirectory = TapasSettings().actaDirectory
    var waveform = ActaWaveformHistory()
    var companionNeedsDetails: Bool {
        snapshot.phase == .saved || snapshot.phase == .recovery || error != nil || snapshot.message != nil
    }
    var companionSize: NSSize {
        NSSize(width: companionNeedsDetails ? 340 : 180,
               height: companionNeedsDetails ? (hasSession ? 400 : 180) : 176)
    }
    var receiptVisible = false
    var showingSavedReceipt = false
    var hasSession: Bool { snapshot.phase != .idle && snapshot.phase != .saved }
    var status: String {
        switch snapshot.phase {
        case .idle: "Ready for a conversation"
        case .recording: "Recording"
        case .paused: "Paused · no audio capture"
        case .finishing: "Finishing your transcript"
        case .saved: "Saved on this Mac"
        case .recovery: "Your meeting needs attention"
        }
    }
}

@MainActor
final class ActaController: NSObject, NSWindowDelegate {
    let model = ActaModel()
    private var session: ActaSession?
    private let recorder = ActaRecorder()
    var onShow: () -> Void = {}
    var isPresented: () -> Bool = { false }
    private var companion: NSPanel?
    private var canResumeCapture = false
    private var captureFailure: String?
    var permissionStatus: () -> (microphone: Bool, appAudio: Bool) = {
        (AVCaptureDevice.authorizationStatus(for: .audio) == .authorized, CGPreflightScreenCaptureAccess())
    }
    var dictadoIsBusy: () -> Bool = { false }
    var onSaved: () -> Void = {}
    var onCaptureStarted: () -> Void = {}
    var onSetup: () -> Void = {}

    func configure(pipeline: TranscriptionPipeline, root: URL) async {
        model.outputDirectory = root.appendingPathComponent("acta", isDirectory: true)
        let recovery = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tapas/ActaRecovery", isDirectory: true)
        let session = ActaSession(pipeline: pipeline, recoveryRoot: recovery, outputDirectory: root.appendingPathComponent("acta", isDirectory: true))
        self.session = session
        do { try await session.recover(); model.ready = true }
        catch { model.error = "Acta’s recovery folder couldn’t be read. Your existing files are kept. Check ~/Library/Application Support/Tapas/ActaRecovery before starting another meeting." }
        recorder.onFailure = { [weak self] message in Task { @MainActor in self?.captureFailure = message } }
        await refresh()
    }

    func setOutputDirectory(_ directory: URL) async {
        model.outputDirectory = directory
        await session?.setOutputDirectory(directory)
    }

    var isWindowVisible: Bool { isPresented() }

    /// The prompt identifies microphone use; accepting records microphone + computer audio.
    func startSuggested(_ app: MicrophoneApp) async {
        guard !model.busy else { return }
        refreshPermissions()
        guard !model.hasSession else { show(); return }
        guard model.ready, model.microphoneGranted, model.appAudioGranted else { show(); return }
        await start()
    }

    func show() {
        model.showingSavedReceipt = false
        model.receiptVisible = false
        refreshPermissions()
        onShow()
        companion?.orderOut(nil)
    }

    func openSavedTranscript() {
        guard let url = model.snapshot.savedURL else { return }
        NSWorkspace.shared.open(url)
    }

    func refreshPermissions() {
        let status = permissionStatus()
        model.microphoneGranted = status.microphone
        model.appAudioGranted = status.appAudio
    }

    func allowAppAudio() async {
        guard !model.busy, !model.hasSession else { return }
        model.appAudioGranted = CGRequestScreenCaptureAccess()
        if !model.appAudioGranted { model.error = "Allow tapas in System Settings → Privacy & Security → Screen & System Audio Recording. If macOS asks you to reopen tapas, do so, then return to Acta." }
    }

    func openAppAudioSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    func allowMicrophone() async {
        model.microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
        if !model.microphoneGranted { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }
    }

    func start() async {
        guard !model.busy, model.ready, let session, !model.hasSession else { return }
        guard !dictadoIsBusy() else { model.error = "Finish your Dictado take or setup before starting Acta."; return }
        guard model.microphoneGranted, model.appAudioGranted else { return }
        if model.snapshot.phase == .saved {
            await newMeeting()
            guard model.snapshot.phase == .idle, model.ready else { return }
        }
        model.busy = true
        model.error = nil
        captureFailure = nil
        model.elapsed = 0
        model.receiptVisible = false
        model.waveform = ActaWaveformHistory()
        defer { model.busy = false }
        do {
            await session.setOutputDirectory(model.outputDirectory)
            try await session.start(appName: "Computer audio")
            canResumeCapture = true
            try await recorder.start(session: session, offset: 0)
            onCaptureStarted()
        } catch {
            await session.pause(duration: model.elapsed, note: "Capture could not start. Check computer audio and microphone access.")
            model.error = error.localizedDescription
        }
        await refresh()
    }

    func pause(note: String? = nil) async {
        guard !model.busy, let session, model.snapshot.phase == .recording else { return }
        model.busy = true
        defer { model.busy = false }
        let duration = await recorder.stop()
        await session.pause(duration: duration, note: note ?? captureFailure)
        captureFailure = nil
        await refresh()
    }

    func resume() async {
        guard !model.busy, let session, model.canResume else { return }
        guard !dictadoIsBusy() else { model.error = "Finish your Dictado take or setup before resuming Acta."; return }
        model.busy = true
        model.error = nil
        captureFailure = nil
        defer { model.busy = false }
        do {
            try await session.resume()
            guard await session.snapshot().phase == .recording else { model.error = "Finish this meeting to recover its pending audio."; return }
            try await recorder.start(session: session, offset: model.elapsed)
            onCaptureStarted()
        } catch {
            await session.pause(duration: model.elapsed, note: "Capture could not resume. Check microphone and computer audio access.")
            model.error = error.localizedDescription
        }
        await refresh()
    }

    /// Returns only once the recording and queued audio writes have stopped.
    func pauseForDictado() async -> Bool {
        guard !model.busy else { return false }
        if model.snapshot.phase == .recording { await pause(note: "Paused for Dictado. Resume the meeting when you’re ready.") }
        return !model.busy && model.snapshot.phase != .recording && model.snapshot.phase != .finishing
    }

    func finish() async {
        guard !model.busy, let session, model.hasSession else { return }
        model.busy = true
        model.error = nil
        defer { model.busy = false }
        if model.snapshot.phase == .recording {
            let duration = await recorder.stop()
            await session.pause(duration: duration, note: captureFailure)
        }
        captureFailure = nil
        model.snapshot.phase = .finishing
        await session.finish()
        await refresh()
        if model.snapshot.phase == .saved {
            model.showingSavedReceipt = true
            onSaved()
            model.receiptVisible = !isPresented()
        }
        updateCompanion()
    }

    func refresh() async {
        model.microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        guard let session else { return }
        model.snapshot = await session.snapshot()
        if model.snapshot.phase == .recording {
            model.elapsed = max(model.snapshot.document?.duration ?? 0, recorder.duration())
            let levels = recorder.levels()
            model.microphoneLevel = levels.microphone; model.appLevel = levels.app
            model.waveform.append(max(levels.microphone, levels.app))
            model.microphoneSeen = levels.microphoneSeen; model.appSeen = levels.appSeen
            if !model.busy {
                if let captureFailure { await pause(note: captureFailure) }
                else if let message = model.snapshot.message { await pause(note: message) }

            }
        } else {
            model.elapsed = model.snapshot.document?.duration ?? 0
            model.waveform = ActaWaveformHistory()
        }
        model.canResume = model.snapshot.phase == .paused && canResumeCapture
        updateCompanion()
    }

    private func updateCompanion() {
        guard model.hasSession || model.receiptVisible, !isPresented() else { companion?.orderOut(nil); return }
        if companion == nil {
            let panel = NSPanel(contentRect: NSRect(origin: .zero, size: model.companionSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.contentView = NSHostingView(rootView: ActaCompanion(model: model, controller: self))
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
                panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - model.companionSize.width - 20, y: screen.visibleFrame.minY + 24))
            }
            companion = panel
        }
        if let companion, companion.frame.size != model.companionSize {
            let old = companion.frame
            companion.setFrame(NSRect(x: old.maxX - model.companionSize.width, y: old.minY,
                                      width: model.companionSize.width, height: model.companionSize.height), display: true)
        }
        companion?.orderFrontRegardless()
    }

    func dismissReceipt() {
        model.receiptVisible = false
        updateCompanion()
    }

    func discard() async {
        guard !model.busy, let session, [.paused, .recovery].contains(model.snapshot.phase) else { return }
        let alert = NSAlert()
        alert.messageText = "Discard this meeting?"
        alert.informativeText = "This removes the transcript and its temporary recovery audio. Export any words you want to keep first."
        alert.addButton(withTitle: "Keep meeting")
        alert.addButton(withTitle: "Discard meeting")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        model.busy = true
        defer { model.busy = false }
        do { try await session.discard(); model.error = nil; canResumeCapture = false }
        catch { model.error = "The recovery files couldn’t be removed. Your meeting is still available." }
        await refresh()
    }

    func export() {
        guard let document = model.snapshot.document else { return }
        let panel = NSSavePanel()
        panel.title = "Keep your meeting transcript"
        panel.nameFieldStringValue = "acta-\(HistoryWriter.filename(for: document.startedAt))"
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do { try document.markdown.write(to: url, atomically: true, encoding: .utf8) }
            catch { self?.model.error = "Export failed. Your meeting is still available here." }
        }
    }

    func newMeeting() async {
        guard !model.busy, model.snapshot.phase == .saved else { return }
        model.busy = true
        defer { model.busy = false }
        model.showingSavedReceipt = false
        // Surface any older interrupted meeting before creating another one.
        do { try await session?.newMeeting() }
        catch { model.error = "An older recovery file couldn’t be read. Check ActaRecovery before starting another meeting."; model.ready = false }
        model.elapsed = 0
        canResumeCapture = false
        await refresh()
    }
}
