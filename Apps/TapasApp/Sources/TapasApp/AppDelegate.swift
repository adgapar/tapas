import AppKit
@preconcurrency import ApplicationServices
import Foundation
import TapasCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var session: DictationSession?
    private let paster = RoutingPaster()
    private var menu: MenuBarController?
    private var setup: SetupWindowController?
    private let overlay = OverlayPanel()
    private let acta = ActaController()
    private let meetingPrompt = MeetingPromptController()
    private let updater = AppUpdater()
    private let hotkey = HotkeyMonitor()
    private let mic = MicRecorder()
    private let catalog = DesertCatalog()
    private let model = PlateModel()
    private var prepareTask: Task<Void, Error>?
    private var refreshTask: Task<Void, Never>?
    private var historyTask: Task<Void, Never>?
    private var indexTask: Task<Void, Never>?
    private var pendingIndexRoots: Set<URL> = []
    private var lastHistoryURL: URL?
    private var previousApplication: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?
    private var dictadoRequested = false
    private var noticeTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationMenu()
        let defaults = UserDefaults.standard
        model.settings.meetingPromptsEnabled = defaults.object(forKey: "meetingPromptsEnabled") as? Bool ?? true
        model.settings.overlayEnabled = defaults.object(forKey: "overlayEnabled") as? Bool ?? true
        model.settings.historyEnabled = defaults.object(forKey: "historyEnabled") as? Bool ?? true
        if let data = defaults.data(forKey: "hotkey"), let value = try? JSONDecoder().decode(Hotkey.self, from: data) { model.settings.hotkey = value }
        if let path = defaults.string(forKey: "transcriptDirectory") { model.settings.transcriptDirectory = URL(fileURLWithPath: path, isDirectory: true) }
        if let data = defaults.data(forKey: "actaHotkey"), let value = try? JSONDecoder().decode(Hotkey.self, from: data), value.isActaShortcut { model.settings.actaHotkey = value }
        if model.settings.hotkey.conflicts(with: model.settings.actaHotkey) {
            model.settings.actaHotkey = [Hotkey.actaStandard, Hotkey(keyCode: 46, modifiers: [.option, .command]), Hotkey(keyCode: 46, modifiers: [.shift, .option])].first { !$0.conflicts(with: model.settings.hotkey) } ?? .actaStandard
        }
        acta.model.outputDirectory = model.settings.actaDirectory
        hotkey.actaHotkey = model.settings.actaHotkey
        hotkey.hotkey = model.settings.hotkey
        overlay.model.shortcut = model.settings.hotkey.label
        hotkey.onTap = { [weak self] in Task { await self?.talk() } }
        hotkey.onCancel = { [weak self] in Task { await self?.cancel() } }
        hotkey.onActa = { [weak self] in Task { @MainActor in self?.acta.show() } }
        hotkey.onRecorded = { [weak self] value in Task { @MainActor in
            guard let self else { return }
            if self.model.recordingActaShortcut { self.applyActaHotkey(value) } else { self.applyHotkey(value) }
        } }
        hotkey.onRecordCancelled = { [weak self] in Task { @MainActor in self?.finishShortcutRecording() } }
        hotkey.installLocalMonitor()
        acta.dictadoIsBusy = { [weak self] in
            guard let self else { return true }
            return dictadoRequested || model.snapshot.phase.isActive || setup?.window?.isVisible == true
        }
        acta.onSaved = { [weak self] in
            guard let self else { return }
            if let url = acta.model.snapshot.savedURL { queueIndex(root: url.deletingLastPathComponent().deletingLastPathComponent()) }
            reloadHistory()
        }
        acta.onSetup = { [weak self] in self?.presentSetup() }
        let actions = makeActions()
        overlay.configure(actions: actions)
        menu = MenuBarController(model: model, actions: actions, actaController: acta)
        menu?.onOpen = { [weak self] in
            self?.acta.dismissReceipt()
            self?.acta.refreshPermissions()
            self?.rememberApplication()
            self?.reloadHistory()
        }
        acta.onShow = { [weak self] in
            self?.model.tab = "Tools"
            self?.model.selectedTool = "Acta"
            self?.menu?.showHome()
        }
        acta.onCaptureStarted = { [weak self] in self?.menu?.close() }
        acta.isPresented = { [weak self] in
            guard let self else { return false }
            return model.tab == "Tools" && model.selectedTool == "Acta" && menu?.isShown == true
        }
        rememberApplication()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in
                if app.processIdentifier != ProcessInfo.processInfo.processIdentifier { self?.previousApplication = app }
                else {
                    self?.acta.refreshPermissions()
                }
            }
        }
        meetingPrompt.enabled = model.settings.meetingPromptsEnabled
        meetingPrompt.canPrompt = { [weak self] in
            guard let self else { return false }
            return !acta.model.busy && !acta.isWindowVisible && !dictadoRequested
                && !model.snapshot.phase.isActive && model.snapshot.phase != .recovery
                && setup?.window?.isVisible != true
        }
        meetingPrompt.isReady = { [weak self] in
            guard let self else { return false }
            acta.refreshPermissions()
            return acta.model.ready && acta.model.microphoneGranted && acta.model.appAudioGranted
        }
        meetingPrompt.actaInProgress = { [weak self] in self?.acta.model.hasSession == true }
        meetingPrompt.onStart = { [weak self] app in Task { await self?.acta.startSuggested(app) } }
        meetingPrompt.onAvailability = { [weak self] message in self?.model.meetingDetectionError = message }
        meetingPrompt.start()
        updater.isBusy = { [weak self] in
            guard let self else { return true }
            return dictadoRequested || model.snapshot.phase.isActive || model.snapshot.phase == .recovery
                || acta.model.hasSession || acta.model.busy || setup?.window?.isVisible == true
        }
        model.updates = updater.model
        updater.start()
        startRefreshing()
        reloadHistory()
        Task {
            // Existing users who closed setup after downloading models can
            // still use their cached models without repeating the walkthrough.
            let cachedModels = await catalog.isDownloaded
            if defaults.bool(forKey: "setupComplete") || cachedModels {
                try? await prepareModels()
            }
        }
        if !defaults.bool(forKey: "setupComplete"), !defaults.bool(forKey: "setupWelcomeSeen"), !defaults.bool(forKey: "setupPresented") {
            presentSetup()
        } else { menu?.showHome() }
        tapasLog("launched Gráfico trusted=\(AXIsProcessTrusted())")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPlate()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func showPlate() {
        if setup?.window?.isVisible == true { setup?.window?.close() }
        menu?.showHome()
    }

    @objc private func showPreferences() {
        model.tab = "Preferences"
        showPlate()
    }

    @objc private func checkForUpdates() { updater.check() }
    @objc private func openSetup() { presentSetup(replayEntrance: true) }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action != #selector(checkForUpdates) || model.updates.canCheck
    }

    private func configureApplicationMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Tapas")
        func add(_ title: String, _ action: Selector, _ key: String = "") {
            let item = appMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
            item.target = self
        }
        add("Show Tapas", #selector(showPlate), "0")
        add("Preferences…", #selector(showPreferences), ",")
        add("Setup…", #selector(openSetup))
        add("Check for Updates…", #selector(checkForUpdates))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Tapas", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Tapas", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        bar.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: NSSelectorFromString(action), keyEquivalent: key)
        }
        editItem.submenu = edit
        bar.addItem(editItem)
        let windowItem = NSMenuItem()
        let windows = NSMenu(title: "Window")
        windows.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windows.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windows
        bar.addItem(windowItem)
        NSApp.mainMenu = bar
        NSApp.windowsMenu = windows
    }

    private func makeActions() -> PlateActions {
        PlateActions(
            talk: { [weak self] in Task { await self?.talk(fromUI: true) } },
            setup: { [weak self] in self?.presentSetup(replayEntrance: true) },
            setHotkey: { [weak self] in self?.applyHotkey($0) },
            recordHotkey: { [weak self] in
                guard let self, !model.snapshot.phase.isActive else { return }
                finishShortcutRecording()
                model.shortcutError = nil
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
            quit: { NSApp.terminate(nil) },
            close: { [weak self] in self?.finishShortcutRecording(); self?.menu?.close() },
            cancelShortcutRecording: { [weak self] in self?.finishShortcutRecording() },
            acta: { [weak self] in self?.acta.show() },
            recordActaHotkey: { [weak self] in
                guard let self, !model.snapshot.phase.isActive else { return }
                finishShortcutRecording()
                model.shortcutError = nil
                model.recordingActaShortcut = true
                hotkey.recording = true
            },
            resetActaHotkey: { [weak self] in self?.applyActaHotkey(.actaStandard) },
            chooseFolder: { [weak self] in self?.chooseTranscriptFolder() },
            resetFolder: { [weak self] in self?.setTranscriptFolder(TapasSettings().transcriptDirectory) },
            checkForUpdates: { [weak self] in self?.menu?.close(); self?.updater.check() },
            setUpdateChecks: { [weak self] in self?.updater.setAutomaticChecks($0) },
            setUpdateDownloads: { [weak self] in self?.updater.setAutomaticDownloads($0) },
            assistantAction: { [weak self] in self?.assistantAction($0) }
        )
    }

    private func presentSetup(replayEntrance: Bool = false) {
        acta.dismissReceipt()
        finishShortcutRecording()
        menu?.close()
        if setup?.window?.isVisible == true { setup?.show(); return }
        // Never switch an active take into practice or discard retained words.
        guard !model.snapshot.phase.isActive, model.snapshot.phase != .recovery, !acta.model.hasSession, !acta.model.busy else {
            showNotice("Finish or recover your current recording before opening setup.")
            menu?.show()
            return
        }
        if let setup, setup.model.flow.phase != .finished {
            if replayEntrance { setup.setStage(0); setup.model.entered = false }
            setup.show(); return
        }
        var flow = SetupFlow.start(microphoneGranted: model.microphoneGranted, accessibilityTrusted: AXIsProcessTrusted(), modelsReady: session != nil)
        if let previous = setup?.model.flow, previous.phase != .finished { flow = previous }
        if !UserDefaults.standard.bool(forKey: "setupComplete"), !UserDefaults.standard.bool(forKey: "setupWelcomeSeen") { flow.phase = .peek }
        flow.hotkeyLabel = model.settings.hotkey.label
        let controller = SetupWindowController(flow: flow)
        controller.setStage(UserDefaults.standard.bool(forKey: "setupComplete") ? 0 : UserDefaults.standard.integer(forKey: "onboardingStage"))
        controller.model.entered = controller.model.stage > 0 || UserDefaults.standard.bool(forKey: "setupBarEntered") || UserDefaults.standard.bool(forKey: "setupWelcomeSeen") || UserDefaults.standard.bool(forKey: "setupComplete")
        if replayEntrance { controller.setStage(0); controller.model.entered = false }
        controller.onEntered = { UserDefaults.standard.set(true, forKey: "setupBarEntered") }
        controller.model.transcriptDirectory = model.settings.transcriptDirectory
        controller.model.folderConfirmed = UserDefaults.standard.bool(forKey: "transcriptFolderConfirmed")
        controller.onStageChanged = { UserDefaults.standard.set($0, forKey: "onboardingStage") }
        controller.allowAppAudio = { [weak self, weak controller] in
            await self?.acta.allowAppAudio()
            controller?.model.flow.modelError = self?.acta.model.error
        }
        controller.appAudioGranted = { CGPreflightScreenCaptureAccess() }
        controller.chooseFolder = { [weak self] in self?.chooseTranscriptFolder() }
        controller.defaultFolder = { [weak self] in self?.setTranscriptFolder(TapasSettings().transcriptDirectory) }
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
                menu?.showHome()
            }
        }
        paster.onPractice = { [weak controller] text in controller?.model.practiceText = text }
        setup = controller
        UserDefaults.standard.set(true, forKey: "setupPresented")
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
            let pipeline = TranscriptionPipeline(recognizer: VozRecognizer(voz: voz), ear: EarDetector(ear: catalog.ear), fillers: UhmAnalyzer(uhm: catalog.uhm))
            let created = DictationSession(
                pipeline: pipeline,
                paster: paster,
                history: HistoryWriter(directory: model.settings.historyDirectory, redactor: DesertRedactor(redactor: catalog.redactor)),
                models: catalog, microphone: mic)
            await created.setHistoryEnabled(model.settings.historyEnabled)
            session = created
            mic.onSamples = { samples in Task { await created.ingest(samples: samples, sampleRate: 16_000) } }
            model.ready = true
            await acta.configure(pipeline: pipeline, root: model.settings.transcriptDirectory)
            await created.setHistoryDirectory(model.settings.historyDirectory)
            await acta.setOutputDirectory(model.settings.actaDirectory)
        }
        prepareTask = task
        defer { prepareTask = nil; model.warming = false }
        do { try await task.value }
        catch { model.modelError = "Voice models couldn’t be prepared. Open Setup to retry."; throw error }
    }

    private func talk(fromUI: Bool = false) async {
        guard !dictadoRequested else { return }
        dictadoRequested = true
        defer { dictadoRequested = false }
        if setup?.window?.isVisible == true { await setup?.handleTalk(); return }
        guard let session else { presentSetup(); return }
        let snapshot = await session.snapshot()
        if snapshot.phase == .recovery { menu?.show(); return }
        if snapshot.phase == .listening { await session.toggle(); return }
        guard !snapshot.phase.isActive else { return }
        guard await acta.pauseForDictado() else {
            showNotice("Acta is changing recording state. Try Dictado again in a moment.")
            return
        }
        if fromUI {
            menu?.close()
            previousApplication?.activate()
            try? await Task.sleep(for: .milliseconds(150))
        }
        rememberApplication()
        overlay.pinToCurrentScreen()
        paster.target = previousApplication
        paster.practiceMode = false
        await session.setHistoryEnabled(model.settings.historyEnabled)
        await session.setHistoryDirectory(model.settings.historyDirectory)
        await session.toggle()
        model.snapshot = await session.snapshot()
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
                await acta.refresh()
                updater.refresh()
                model.actaStatus = acta.model.hasSession ? "Acta · \(acta.model.status)" : nil
                model.actaRecording = acta.model.snapshot.phase == .recording
                menu?.update(snap, actaStatus: model.actaStatus)
                overlay.model.showLiveWords = model.settings.overlayEnabled
                overlay.apply(snap, suppressed: setup?.window?.isVisible == true || menu?.isShown == true)
                if snap.historyURL != lastHistoryURL {
                    if let url = snap.historyURL { queueIndex(root: url.deletingLastPathComponent().deletingLastPathComponent()) }
                    lastHistoryURL = snap.historyURL
                    reloadHistory()
                }
                if tick % 10 == 0 {
                    model.microphoneGranted = await mic.isAuthorized
                    model.accessibilityTrusted = AXIsProcessTrusted()
                    if model.accessibilityTrusted { hotkey.startTapIfTrusted() }
                    model.shortcutRunning = hotkey.tapRunning
                    if model.warming { model.progress = await catalog.downloadFraction }
                }
                if tick > 0 && tick % 600 == 0 { reconcileLibrary() }
                tick += 1
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func applyHotkey(_ value: Hotkey) {
        finishShortcutRecording()
        guard !model.snapshot.phase.isActive else { return }
        guard !value.conflicts(with: model.settings.actaHotkey) else {
            model.shortcutError = "This overlaps with Acta’s shortcut. Choose different modifiers."
            return
        }
        model.shortcutError = nil
        model.settings.hotkey = value
        hotkey.hotkey = value
        hotkey.noteTrustMayHaveChanged()
        hotkey.recording = false
        model.recordingShortcut = false
        setup?.model.flow.hotkeyLabel = value.label
        overlay.model.shortcut = value.label
        savePreferences()
    }

    private func finishShortcutRecording() {
        hotkey.recording = false
        model.recordingShortcut = false
        model.recordingActaShortcut = false
    }

    private func applyActaHotkey(_ value: Hotkey) {
        finishShortcutRecording()
        guard !model.snapshot.phase.isActive else { return }
        guard value.isActaShortcut, !value.conflicts(with: model.settings.hotkey) else {
            model.shortcutError = "Use a key with at least two modifiers, different from Dictado’s shortcut."
            return
        }
        model.shortcutError = nil
        model.settings.actaHotkey = value
        hotkey.actaHotkey = value
        hotkey.noteTrustMayHaveChanged()
        savePreferences()
    }

    private func chooseTranscriptFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose your transcript folder"
        panel.message = "Tapas creates dictado and acta subfolders here for new recordings."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = model.settings.transcriptDirectory
        panel.begin { [weak self] response in
            guard response == .OK, let root = panel.url else { return }
            self?.setTranscriptFolder(root)
        }
    }

    private func setTranscriptFolder(_ root: URL) {
        do {
            try TranscriptFolders.prepare(root: root)
            model.settings.transcriptDirectory = root
            acta.model.outputDirectory = model.settings.actaDirectory
            model.folderError = nil
            setup?.model.transcriptDirectory = root
            setup?.model.folderConfirmed = true
            setup?.model.folderError = nil
            UserDefaults.standard.set(true, forKey: "transcriptFolderConfirmed")
            model.selected = nil
            savePreferences()
            Task {
                await session?.setHistoryDirectory(model.settings.historyDirectory)
                await acta.setOutputDirectory(model.settings.actaDirectory)
                reloadHistory()
            }
        } catch {
            model.folderError = "Tapas couldn’t write to that folder. Choose a writable location. Your current folder is unchanged."
            setup?.model.folderError = model.folderError
        }
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(model.settings.transcriptDirectory.path, forKey: "transcriptDirectory")
        reconcileLibrary()
        if let data = try? JSONEncoder().encode(model.settings.actaHotkey) { defaults.set(data, forKey: "actaHotkey") }
        defaults.set(model.settings.meetingPromptsEnabled, forKey: "meetingPromptsEnabled")
        meetingPrompt.enabled = model.settings.meetingPromptsEnabled
        defaults.set(model.settings.overlayEnabled, forKey: "overlayEnabled")
        defaults.set(model.settings.historyEnabled, forKey: "historyEnabled")
        if let data = try? JSONEncoder().encode(model.settings.hotkey) { defaults.set(data, forKey: "hotkey") }
    }

    private func rememberApplication() {
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApplication = app }
    }

    private func reloadHistory() {
        reconcileLibrary()
        historyTask?.cancel()
        let directory = model.settings.historyDirectory
        historyTask = Task { [weak self] in
            do {
                let entries = try await Task.detached {
                    let dictado = try HistoryLibrary.read(directory: directory)
                    let acta = try HistoryLibrary.read(directory: directory.deletingLastPathComponent().appendingPathComponent("acta"))
                    return (dictado + acta).sorted { $0.date > $1.date }
                }.value
                guard !Task.isCancelled else { return }
                self?.model.entries = entries
                self?.model.libraryError = nil
            } catch { self?.model.libraryError = "History couldn’t be read. Check your transcript folder in Preferences." }
        }
    }

    private func reconcileLibrary() {
        do {
            let location = try LibraryLocation.update(root: model.settings.transcriptDirectory)
            for path in [location.current_root] + location.previous_roots {
                queueIndex(root: URL(fileURLWithPath: path, isDirectory: true))
            }
        } catch { model.assistantMessage = "Library discovery couldn’t be updated: " + error.localizedDescription }
        model.assistantStatus = AssistantSkill().status(for: model.assistantHost)
    }

    private func queueIndex(root: URL) {
        pendingIndexRoots.insert(root)
        guard indexTask == nil else { return }
        indexTask = Task { [weak self] in
            guard let self else { return }
            var warnings: [String] = []
            var count = 0
            while let next = pendingIndexRoots.sorted(by: { $0.path < $1.path }).first {
                pendingIndexRoots.remove(next)
                let report = await TranscriptIndex.shared.rebuild(root: next)
                warnings += report.warnings
                count += report.recordings
            }
            model.indexMessage = warnings.isEmpty ? "Indexes ready · \(count) recordings." : "Recordings are safe. " + warnings.joined(separator: "\n")
            indexTask = nil
        }
    }

    private func assistantAction(_ action: String) {
        do {
            let skill = AssistantSkill()
            switch action {
            case "install":
                try LibraryLocation.update(root: model.settings.transcriptDirectory)
                let directory = try skill.install(for: model.assistantHost)
                model.assistantMessage = "Installed at \(directory.path). Start a new assistant session to load it."
            case "remove":
                try skill.remove(for: model.assistantHost)
                model.assistantMessage = "Skill removed. Recordings are unchanged."
            case "copy":
                if let executable = Bundle.main.executableURL {
                    copy(AssistantSkill.setupCommand(executable: executable, host: model.assistantHost))
                    model.assistantMessage = "Setup command copied. Run it locally to install the skill."
                }
            case "rebuild": reconcileLibrary()
            default: break
            }
        } catch { model.assistantMessage = error.localizedDescription }
        model.assistantStatus = AssistantSkill().status(for: model.assistantHost)
    }

    private func revealHistory() {
        do {
            let root = model.settings.historyDirectory.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            NSWorkspace.shared.open(root)
        } catch { showNotice("The transcript folder couldn’t be opened. Check its location in Preferences.") }
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
        if acta.model.hasSession || acta.model.busy {
            showNotice("Finish and save your Acta meeting before quitting.")
            acta.show()
            return .terminateCancel
        }
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
        refreshTask?.cancel(); historyTask?.cancel(); indexTask?.cancel(); noticeTask?.cancel()
        hotkey.stop()
        meetingPrompt.stop()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }
}
