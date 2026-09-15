import AppKit
@preconcurrency import ApplicationServices
import Foundation
import TapasCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var session: DictationSession?
    private let paster = RoutingPaster()
    private var menu: MenuBarController?
    private var setup: SetupWindowController?
    private let overlay = OverlayPanel()
    private let hotkey = HotkeyMonitor()
    private let mic = MicRecorder()
    private let catalog = DesertCatalog()
    private let model = PlateModel()
    private var prepareTask: Task<Void, Error>?
    private var refreshTask: Task<Void, Never>?
    private var historyTask: Task<Void, Never>?
    private var lastHistoryURL: URL?
    private var previousApplication: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?
    private var trustWasGranted = false
    private var noticeTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        model.settings.overlayEnabled = defaults.object(forKey: "overlayEnabled") as? Bool ?? true
        model.settings.historyEnabled = defaults.object(forKey: "historyEnabled") as? Bool ?? true
        if let data = defaults.data(forKey: "hotkey"), let value = try? JSONDecoder().decode(Hotkey.self, from: data) { model.settings.hotkey = value }
        hotkey.hotkey = model.settings.hotkey
        overlay.model.shortcut = model.settings.hotkey.label
        hotkey.onTap = { [weak self] in Task { await self?.talk() } }
        hotkey.onCancel = { [weak self] in Task { await self?.cancel() } }
        hotkey.onRecorded = { [weak self] value in Task { @MainActor in self?.applyHotkey(value) } }
        hotkey.onRecordCancelled = { [weak self] in Task { @MainActor in self?.model.recordingShortcut = false } }
        hotkey.installLocalMonitor()
        let actions = makeActions()
        overlay.configure(actions: actions)
        menu = MenuBarController(model: model, actions: actions)
        menu?.onOpen = { [weak self] in
            self?.rememberApplication()
            self?.reloadHistory()
        }
        rememberApplication()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in
                if app.processIdentifier != ProcessInfo.processInfo.processIdentifier { self?.previousApplication = app }
            }
        }
        startRefreshing()
        reloadHistory()
        if defaults.bool(forKey: "setupComplete") {
            Task { try? await prepareModels() }
        } else { presentSetup() }
        tapasLog("launched Gráfico trusted=\(AXIsProcessTrusted())")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if UserDefaults.standard.bool(forKey: "setupComplete") { menu?.show() } else { presentSetup() }
        return true
    }

    private func makeActions() -> PlateActions {
        PlateActions(
            talk: { [weak self] in Task { await self?.talk(fromUI: true) } },
            setup: { [weak self] in self?.presentSetup() },
            setHotkey: { [weak self] in self?.applyHotkey($0) },
            recordHotkey: { [weak self] in
                guard let self, !model.snapshot.phase.isActive else { return }
                model.recordingShortcut = true
                hotkey.recording = true
            },
            preferencesChanged: { [weak self] in self?.savePreferences() },
            folder: { [weak self] in self?.revealHistory() },
            copy: { [weak self] in self?.copy($0) },
            export: { [weak self] in self?.export($0) },
            dismiss: { [weak self] in self?.dismissResult() },
            retryPaste: { [weak self] in Task { await self?.retryPaste() } },
            retrySave: { [weak self] in Task { await self?.session?.retrySave(); self?.reloadHistory() } },
            cancel: { [weak self] in Task { await self?.cancel() } },
            quit: { NSApp.terminate(nil) }
        )
    }

    private func presentSetup() {
        menu?.close()
        if setup?.window?.isVisible == true { setup?.show(); return }
        // Never switch an active take into practice or discard retained words.
        guard !model.snapshot.phase.isActive, model.snapshot.phase != .recovery else {
            showNotice("Finish or recover your current take before opening setup.")
            menu?.show()
            return
        }
        var flow = SetupFlow.start(microphoneGranted: model.microphoneGranted, accessibilityTrusted: AXIsProcessTrusted(), modelsReady: session != nil)
        if let previous = setup?.model.flow, previous.phase != .finished { flow = previous }
        if !UserDefaults.standard.bool(forKey: "setupComplete"), !UserDefaults.standard.bool(forKey: "setupWelcomeSeen") { flow.phase = .peek }
        flow.hotkeyLabel = model.settings.hotkey.label
        let controller = SetupWindowController(flow: flow)
        controller.allowMicrophone = { [mic] in
            let granted = await mic.requestAuthorization()
            if !granted { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }
            return granted
        }
        controller.microphoneGranted = { [mic] in await mic.isAuthorized }
        controller.openAccessibility = { promptAccessibilityTrust() }
        controller.pollAccessibility = { [weak self] in
            let trusted = AXIsProcessTrusted()
            return (trusted, self?.hotkey.tapRunning == true)
        }
        controller.retryAccessibility = { [weak self] in
            let trusted = AXIsProcessTrusted()
            if trusted { self?.hotkey.noteTrustMayHaveChanged() }
            return (trusted, self?.hotkey.tapRunning == true)
        }
        controller.downloadModels = { [weak self] in try await self?.prepareModels() }
        controller.downloadFraction = { [catalog] in await catalog.downloadFraction }
        controller.modelsReady = { [weak self] in self?.session != nil }
        controller.onHotkey = { [weak self] in self?.applyHotkey($0) }
        controller.onPracticeToggle = { [weak self] in
            guard let self, let session else { return }
            paster.practiceMode = true
            await session.setHistoryEnabled(false)
            await session.toggle()
        }
        controller.practiceSnapshot = { [weak self] in await self?.session?.snapshot() ?? OverlaySnapshot() }
        controller.onCancel = { [weak self] in Task { await self?.cancel() } }
        controller.onFinished = { [weak self] in
            UserDefaults.standard.set(true, forKey: "setupComplete")
            self?.showNotice("Ready with gusto. Your next thought is one shortcut away.")
        }
        controller.onDismissed = { [weak self] in
            guard let self else { return }
            Task {
                // Closing practice cancels capture, but lets an in-flight final pass finish in practice mode.
                await session?.silence()
                while await session?.snapshot().phase == .finishing { try? await Task.sleep(for: .milliseconds(30)) }
                paster.practiceMode = false
                await session?.setHistoryEnabled(model.settings.historyEnabled)
            }
        }
        paster.onPractice = { [weak controller] text in controller?.model.practiceText = text }
        setup = controller
        controller.show()
    }

    private func prepareModels() async throws {
        if session != nil { return }
        if let prepareTask { return try await prepareTask.value }
        model.warming = true
        model.modelError = nil
        let task = Task { [self] in
            try await catalog.download()
            let voz = try await makeVoz()
            let created = DictationSession(
                pipeline: TranscriptionPipeline(recognizer: VozRecognizer(voz: voz), ear: EarDetector(ear: catalog.ear), fillers: UhmAnalyzer(uhm: catalog.uhm)),
                paster: paster,
                history: HistoryWriter(directory: model.settings.historyDirectory, redactor: DesertRedactor(redactor: catalog.redactor)),
                models: catalog, microphone: mic)
            await created.setHistoryEnabled(model.settings.historyEnabled)
            session = created
            mic.onSamples = { samples in Task { await created.ingest(samples: samples, sampleRate: 16_000) } }
            model.ready = true
        }
        prepareTask = task
        defer { prepareTask = nil; model.warming = false }
        do { try await task.value }
        catch { model.modelError = "Voice models couldn’t be prepared. Open Setup to retry."; throw error }
    }

    private func talk(fromUI: Bool = false) async {
        if setup?.window?.isVisible == true { await setup?.handleTalk(); return }
        guard let session else { presentSetup(); return }
        let snapshot = await session.snapshot()
        if snapshot.phase == .recovery { menu?.show(); return }
        if snapshot.phase == .listening { await session.toggle(); return }
        guard !snapshot.phase.isActive else { return }
        if fromUI {
            menu?.close()
            previousApplication?.activate()
            try? await Task.sleep(for: .milliseconds(150))
        }
        rememberApplication()
        paster.target = previousApplication
        paster.practiceMode = false
        await session.setHistoryEnabled(model.settings.historyEnabled)
        await session.toggle()
    }

    private func cancel() async {
        await session?.silence()
    }

    private func retryPaste() async {
        menu?.close()
        // Retry explicitly returns to the original destination; never paste into an unrelated app.
        paster.target?.activate()
        try? await Task.sleep(for: .milliseconds(150))
        await session?.retryPaste()
    }

    private func startRefreshing() {
        refreshTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                let snap = await session?.snapshot() ?? OverlaySnapshot()
                if model.snapshot != snap { model.snapshot = snap }
                menu?.update(snap)
                var visible = snap
                if setup?.window?.isVisible == true || menu?.isShown == true { visible.isVisible = false }
                else if !model.settings.overlayEnabled && snap.phase != .recovery && snap.phase != .failed { visible.isVisible = false }
                overlay.apply(visible)
                if snap.historyURL != lastHistoryURL {
                    lastHistoryURL = snap.historyURL
                    reloadHistory()
                }
                if tick % 10 == 0 {
                    model.microphoneGranted = await mic.isAuthorized
                    model.accessibilityTrusted = AXIsProcessTrusted()
                    if model.accessibilityTrusted && !trustWasGranted { hotkey.noteTrustMayHaveChanged() }
                    trustWasGranted = model.accessibilityTrusted
                    model.shortcutRunning = hotkey.tapRunning
                    if model.warming { model.progress = await catalog.downloadFraction }
                }
                tick += 1
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func applyHotkey(_ value: Hotkey) {
        guard !model.snapshot.phase.isActive else { return }
        model.settings.hotkey = value
        hotkey.hotkey = value
        hotkey.recording = false
        model.recordingShortcut = false
        setup?.model.flow.hotkeyLabel = value.label
        overlay.model.shortcut = value.label
        savePreferences()
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(model.settings.overlayEnabled, forKey: "overlayEnabled")
        defaults.set(model.settings.historyEnabled, forKey: "historyEnabled")
        if let data = try? JSONEncoder().encode(model.settings.hotkey) { defaults.set(data, forKey: "hotkey") }
    }

    private func rememberApplication() {
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApplication = app }
    }

    private func reloadHistory() {
        historyTask?.cancel()
        let directory = model.settings.historyDirectory
        historyTask = Task { [weak self] in
            do {
                let entries = try await Task.detached { try HistoryLibrary.read(directory: directory) }.value
                guard !Task.isCancelled else { return }
                self?.model.entries = entries
                self?.model.libraryError = nil
            } catch { self?.model.libraryError = "History couldn’t be read. Check access to Documents/tapas/dictado." }
        }
    }

    private func revealHistory() {
        do {
            try FileManager.default.createDirectory(at: model.settings.historyDirectory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(model.settings.historyDirectory)
        } catch { showNotice("The history folder couldn’t be opened. Check access to Documents.") }
    }

    private func dismissResult() {
        if model.snapshot.phase == .recovery {
            let alert = NSAlert()
            alert.messageText = "Dismiss these words?"
            alert.informativeText = "Copy or export anything you still need first."
            alert.addButton(withTitle: "Keep words")
            alert.addButton(withTitle: "Dismiss result")
            guard alert.runModal() == .alertSecondButtonReturn else { return }
        }
        Task { await session?.dismissResult() }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        let copied = NSPasteboard.general.setString(text, forType: .string)
        showNotice(copied ? "Copied. Ready to use where you need it." : "Copy failed. Export a file to keep your words.")
    }

    private func export(_ text: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "dictado-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-" )).md"
        panel.title = "Keep your words"
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                self?.showNotice("Your words are saved.")
            } catch { self?.showNotice("The file couldn’t be saved. Your words are still available.") }
        }
    }

    private func showNotice(_ text: String) {
        noticeTask?.cancel()
        model.notice = text
        overlay.model.notice = text
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.model.notice = nil
            self?.overlay.model.notice = nil
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model.snapshot.phase == .finishing {
            showNotice("Dictado is finishing your words. Try quitting again once they’re ready.")
            menu?.show()
            return .terminateCancel
        }
        if model.snapshot.phase.isActive || model.snapshot.phase == .recovery {
            let alert = NSAlert()
            alert.messageText = model.snapshot.phase == .recovery ? "Quit with words still waiting?" : "Quit during this take?"
            alert.informativeText = "Unsaved words will be lost. Stay in Tapas to finish, copy or export them."
            alert.addButton(withTitle: "Stay in Tapas")
            alert.addButton(withTitle: "Quit Tapas")
            return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTask?.cancel(); historyTask?.cancel(); noticeTask?.cancel()
        hotkey.stop()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }
}
