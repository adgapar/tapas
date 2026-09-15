import AppKit
import SwiftUI
import TapasCore

@MainActor
final class SetupWindowController: NSWindowController, NSWindowDelegate {
    var onFinished: (() -> Void)?
    var onDismissed: (() -> Void)?
    var allowMicrophone: (() async -> Bool)?
    var microphoneGranted: (() async -> Bool)?
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

    init(flow: SetupFlow) {
        model = SetupModel(flow: flow)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 560),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "A first taste of Tapas"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: SetupView(
            model: model,
            onPrimary: { [weak self] in await self?.primary() },
            onSecondary: { [weak self] in self?.openAccessibility?() },
            onSkip: { [weak self] in self?.window?.close() },
            onPractice: { [weak self] in await self?.handleTalk() },
            onCancel: { [weak self] in self?.onCancel?() },
            onHotkey: { [weak self] value in self?.onHotkey?(value) },
            onRecheckAccessibility: { [weak self] in self?.recheckAccessibility() },
            onRevealApplication: { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
        ))
        window.appearance = NSAppearance(named: .aqua)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show() {
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
        guard model.flow.phase == .accessibility else { return }
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
        model.flow.modelsReady = modelsReady?() ?? false
        if model.downloading, let downloadFraction { model.flow.downloadFraction = await downloadFraction() }
        if model.flow.phase == .tryIt, let snap = await practiceSnapshot?() {
            model.phase = snap.phase
            if !snap.committedText.isEmpty { model.practiceText = snap.committedText }
            if snap.phase == .delivered { model.completedPractice = true }
            model.flow.modelError = snap.phase == .failed || snap.phase == .recovery ? snap.message : nil
        }
    }

    private func primary() async {
        guard !model.busy else { return }
        switch model.flow.phase {
        case .peek:
            UserDefaults.standard.set(true, forKey: "setupWelcomeSeen")
            model.flow.advance()
        case .microphone:
            model.busy = true
            model.flow.microphoneGranted = await allowMicrophone?() ?? false
            model.busy = false
            if model.flow.microphoneGranted {
                model.flow.modelError = nil
                model.flow.advance()
            } else {
                model.flow.modelError = "Microphone access is off. Enable Tapas in Privacy & Security → Microphone, then return here."
            }
        case .accessibility:
            recheckAccessibility()
            model.flow.modelError = nil
            model.flow.advance()
        case .kitchen:
            if model.flow.modelsReady { model.flow.advance() }
            else { await prepare() }
        case .tryIt:
            guard model.completedPractice, !model.phase.isActive else { return }
            model.flow.advance()
        case .finished:
            onFinished?()
            window?.close()
        }
        if model.flow.phase == .kitchen, !model.flow.modelsReady, model.flow.modelError == nil { await prepare() }
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
        guard model.flow.phase == .tryIt, !model.busy else { return }
        model.busy = true
        defer { model.busy = false }
        if model.phase != .listening { model.practiceText = ""; model.completedPractice = false }
        await onPracticeToggle?()
        await refresh()
    }

    func windowWillClose(_ notification: Notification) {
        pollTask?.cancel()
        pollTask = nil
        onDismissed?()
    }
}
