import AppKit
import AVFoundation
import SwiftUI
import TapasCore

@MainActor @Observable
final class ActaModel {
    var snapshot = ActaSnapshot()
    var apps: [ActaAppSource] = []
    var selectedApp: Int32?
    var busy = false
    var ready = false
    var microphoneGranted = false
    var error: String?
    var elapsed: Double = 0
    var microphoneLevel: Double = 0
    var appLevel: Double = 0
    var microphoneSeen = false
    var appSeen = false
    var canResume = false
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
    private var window: NSWindow?
    private var companion: NSPanel?
    private var source: ActaAppSource?
    private var captureFailure: String?
    var dictadoIsBusy: () -> Bool = { false }
    var onSaved: () -> Void = {}
    var onSetup: () -> Void = {}

    func configure(pipeline: TranscriptionPipeline, root: URL) async {
        let recovery = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tapas/ActaRecovery", isDirectory: true)
        let session = ActaSession(pipeline: pipeline, recoveryRoot: recovery, outputDirectory: root.appendingPathComponent("acta", isDirectory: true))
        self.session = session
        do { try await session.recover(); model.ready = true }
        catch { model.error = "Acta’s recovery folder couldn’t be read. Your existing files are kept. Check ~/Library/Application Support/Tapas/ActaRecovery before starting another meeting." }
        recorder.onFailure = { [weak self] message in Task { @MainActor in self?.captureFailure = message } }
        await refresh()
    }

    var isWindowVisible: Bool { window?.isVisible == true && window?.isMiniaturized != true }

    /// Called only by the explicit Start Acta action in the microphone prompt.
    /// Match the detected process again; never fall back to recording a different app.
    func startSuggested(_ app: MicrophoneApp) async {
        guard !model.busy else { return }
        if model.snapshot.phase == .saved { await newMeeting() }
        show()
        guard !model.hasSession else { return }
        await loadApps()
        guard let selected = model.apps.first(where: { $0.id == app.pid }) else {
            model.selectedApp = nil
            if model.error == nil { model.error = "The detected app is no longer available. Choose a meeting app to continue." }
            return
        }
        model.selectedApp = selected.id
        guard model.ready else { return }
        if !model.microphoneGranted {
            model.busy = true
            await allowMicrophone()
            model.busy = false
        }
        guard model.microphoneGranted else { return }
        await start()
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 650), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Acta · Tapas"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: ActaView(model: model, controller: self))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        companion?.orderOut(nil)
    }

    func loadApps() async {
        guard !model.busy, !model.hasSession else { return }
        model.busy = true
        model.error = nil
        defer { model.busy = false }
        do {
            model.apps = try await ActaRecorder.sources()
            if !model.apps.contains(where: { $0.id == model.selectedApp }) { model.selectedApp = model.apps.first?.id }
            if model.apps.isEmpty { model.error = "Open your meeting app, then refresh this list." }
        } catch {
            model.error = "App audio access is unavailable. Allow Tapas in System Settings → Privacy & Security → Screen & System Audio Recording, then refresh. macOS may ask you to reopen Tapas."
        }
    }

    func allowMicrophone() async {
        model.microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)
        if !model.microphoneGranted { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }
    }

    func start() async {
        guard !model.busy, model.ready, let session, !model.hasSession else { return }
        guard !dictadoIsBusy() else { model.error = "Finish your Dictado take or setup before starting Acta."; return }
        guard let app = model.apps.first(where: { $0.id == model.selectedApp }), model.microphoneGranted else { return }
        model.busy = true
        model.error = nil
        captureFailure = nil
        model.elapsed = 0
        defer { model.busy = false }
        do {
            try await session.start(appName: app.name)
            source = app
            try await recorder.start(app: app, session: session, offset: 0)
        } catch {
            await session.pause(duration: model.elapsed, note: "Capture could not start. Check app audio and microphone access.")
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
        guard !model.busy, let session, let source, model.canResume else { return }
        guard !dictadoIsBusy() else { model.error = "Finish your Dictado take or setup before resuming Acta."; return }
        model.busy = true
        model.error = nil
        captureFailure = nil
        defer { model.busy = false }
        do {
            try await session.resume()
            guard await session.snapshot().phase == .recording else { model.error = "Finish this meeting to recover its pending audio."; return }
            try await recorder.start(app: source, session: session, offset: model.elapsed)
        } catch {
            await session.pause(duration: model.elapsed, note: "Capture could not resume. Check the selected app and audio access.")
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
        if model.snapshot.phase == .saved { onSaved() }
        show()
    }

    func refresh() async {
        model.microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        guard let session else { return }
        model.snapshot = await session.snapshot()
        if model.snapshot.phase == .recording {
            model.elapsed = max(model.snapshot.document?.duration ?? 0, recorder.duration())
            let levels = recorder.levels()
            model.microphoneLevel = levels.microphone; model.appLevel = levels.app
            model.microphoneSeen = levels.microphoneSeen; model.appSeen = levels.appSeen
            if !model.busy {
                if let captureFailure { await pause(note: captureFailure) }
                else if let message = model.snapshot.message { await pause(note: message) }
                else if let source, NSRunningApplication(processIdentifier: source.id) == nil {
                    await pause(note: "The selected app closed. Your recording is kept; finish this meeting to save it.")
                }
            }
        } else { model.elapsed = model.snapshot.document?.duration ?? 0 }
        model.canResume = model.snapshot.phase == .paused && source != nil && NSRunningApplication(processIdentifier: source!.id) != nil
        updateCompanion()
    }

    private func updateCompanion() {
        guard model.hasSession, window?.isVisible != true || window?.isMiniaturized == true else { companion?.orderOut(nil); return }
        if companion == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 330, height: 116), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.contentView = NSHostingView(rootView: ActaCompanion(model: model, controller: self))
            if let screen = NSScreen.main { panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 350, y: screen.visibleFrame.maxY - 140)) }
            companion = panel
        }
        companion?.orderFrontRegardless()
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
        do { try await session.discard(); model.error = nil; source = nil }
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
        // Surface any older interrupted meeting before creating another one.
        do { try await session?.newMeeting() }
        catch { model.error = "An older recovery file couldn’t be read. Check ActaRecovery before starting another meeting."; model.ready = false }
        model.elapsed = 0
        source = nil
        await refresh()
    }
}
