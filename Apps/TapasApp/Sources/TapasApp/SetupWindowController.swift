import AppKit
import SwiftUI
import TapasCore

@MainActor
final class SetupWindowController: NSWindowController, NSWindowDelegate {
    var onFinished: (() -> Void)?
    var onDismissed: (() -> Void)?
    var allowMicrophone: (() async -> Bool)?
    var microphoneGranted: (() async -> Bool)?
    var allowAppAudio: (() async -> Void)?
    var appAudioGranted: (() -> Bool)?
    var chooseFolder: (() -> Void)?
    var defaultFolder: (() -> Void)?
    var onStageChanged: ((Int) -> Void)?
    var openAccessibility: (() -> Void)?
    var retryAccessibility: (() -> (trusted: Bool, tapStarted: Bool))?
    var pollAccessibility: (() -> (trusted: Bool, tapStarted: Bool))?
    var downloadModels: (() async throws -> Void)?
    var downloadFraction: (() async -> Double)?
    var modelsReady: (() -> Bool)?
    var onPracticeToggle: (() async -> Void)?
    var onCancel: (() -> Void)?
    var onHotkey: ((Hotkey) -> Void)?
    var practiceSnapshot: (() async -> OverlaySnapshot)?
    let model: SetupModel
    private var pollTask: Task<Void, Never>?
    private var completionReported = false

    init(flow: SetupFlow) {
        model = SetupModel(flow: flow)
        let window = FloatingWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 730),
                                    styleMask: [.borderless, .closable, .miniaturizable], backing: .buffered, defer: false)
        configureFloatingWindow(window)
        super.init(window: window)
        window.title = "A first taste of Tapas"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let setupModel = model
        window.contentViewController = NSHostingController(rootView: FittedSurface(width: 920, height: 730) { SetupView(
            model: setupModel,
            onPrimary: { [weak self] in await self?.primary() },
            onSecondary: { [weak self] in self?.openAccessibility?() },
            onSkip: { [weak self] in self?.window?.close() },
            onPractice: { [weak self] in await self?.handleTalk() },
            onCancel: { [weak self] in self?.onCancel?() },
            onHotkey: { [weak self] value in self?.onHotkey?(value) },
            onRecheckAccessibility: { [weak self] in self?.recheckAccessibility() },
            onRevealApplication: { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) },
            onBack: { [weak self] in self?.back() },
            onMicrophone: { [weak self] in await self?.requestMicrophone() },
            onAppAudio: { [weak self] in await self?.allowAppAudio?() },
            onChooseFolder: { [weak self] in self?.chooseFolder?() },
            onDefaultFolder: { [weak self] in self?.defaultFolder?() },
            onPrepare: { [weak self] in await self?.prepare() }
        ) })
        window.appearance = NSAppearance(named: .aqua)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show() {
        if let window { placeFloatingWindow(window, preferred: NSSize(width: 920, height: 730)) }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        recheckAccessibility()
    }

    private func recheckAccessibility() {
        guard model.stage == 1 else { return }
        model.accessibilityChecked = true
        if let status = retryAccessibility?() ?? pollAccessibility?() {
            model.flow.accessibilityTrusted = status.trusted
            model.flow.tapStarted = status.tapStarted
        }
    }

    private func refresh() async {
        if let microphoneGranted { model.flow.microphoneGranted = await microphoneGranted() }
        if let (trusted, running) = pollAccessibility?() {
            model.flow.accessibilityTrusted = trusted
            model.flow.tapStarted = running
        }
        model.appAudioGranted = appAudioGranted?() ?? false
        model.flow.modelsReady = modelsReady?() ?? false
        if model.downloading, let downloadFraction { model.flow.downloadFraction = await downloadFraction() }
        if model.flow.phase == .tryIt, let snap = await practiceSnapshot?() {
            model.phase = snap.phase
            model.level = min(1, Double(snap.rms) * 8)
            if !snap.committedText.isEmpty { model.practiceText = snap.committedText }
            if snap.phase == .delivered { model.completedPractice = true }
            model.flow.modelError = snap.phase == .failed || snap.phase == .recovery ? snap.message : nil
        }
    }

    func setStage(_ stage: Int) {
        model.stage = min(3, max(0, stage))
        model.flow.phase = [SetupPhase.peek, .microphone, .kitchen, .tryIt][model.stage]
        model.flow.modelError = nil
        onStageChanged?(model.stage)
    }

    func back() {
        guard !model.phase.isActive, !model.busy else { return }
        setStage(model.stage - 1)
    }

    func primary() async {
        guard !model.busy, !model.phase.isActive else { return }
        if model.stage == 2 && !model.folderConfirmed { return }
        if model.stage == 3 {
            model.flow.phase = .finished
            reportCompletionIfNeeded()
            window?.close()
        } else {
            UserDefaults.standard.set(true, forKey: "setupWelcomeSeen")
            setStage(model.stage + 1)
        }
    }

    private func requestMicrophone() async {
        guard !model.busy else { return }
        model.busy = true
        model.flow.microphoneGranted = await allowMicrophone?() ?? false
        model.busy = false
        model.flow.modelError = model.flow.microphoneGranted ? nil : "Allow Tapas in System Settings → Privacy & Security → Microphone, then return here."
    }

    private func prepare() async {
        guard !model.downloading else { return }
        model.downloading = true
        model.flow.modelError = nil
        defer { model.downloading = false }
        do {
            guard let downloadModels else { return }
            try await downloadModels()
            model.flow.modelsReady = true
            model.flow.downloadFraction = 1
        } catch {
            model.flow.modelError = "The models couldn’t be prepared. Check your connection and free disk space, then try again. Downloaded model files are kept."
        }
    }

    func handleTalk() async {
        guard model.stage == 3, model.flow.modelsReady, model.flow.microphoneGranted, !model.busy else { return }
        model.busy = true
        defer { model.busy = false }
        if model.phase != .listening { model.practiceText = ""; model.completedPractice = false }
        await onPracticeToggle?()
        await refresh()
    }

    func reportCompletionIfNeeded() {
        guard model.flow.phase == .finished, !completionReported else { return }
        completionReported = true
        onFinished?()
    }

    func windowWillClose(_ notification: Notification) {
        reportCompletionIfNeeded()
        pollTask?.cancel()
        pollTask = nil
        onDismissed?()
    }
}
