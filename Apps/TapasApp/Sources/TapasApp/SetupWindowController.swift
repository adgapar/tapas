import AppKit
import QuartzCore
import SwiftUI
import TapasCore

@MainActor
final class SetupWindowController: NSWindowController, NSWindowDelegate {
    var onFinished: (() -> Void)?
    var onDismissed: (() -> Void)?
    var allowMicrophone: (() async -> Bool)?
    var openAccessibility: (() -> Void)?
    var pollAccessibility: (() -> (trusted: Bool, tapStarted: Bool))?
    var downloadModels: (() async throws -> Void)?
    var downloadFraction: (() async -> Double)?
    var modelsReady: (() async -> Bool)?
    var onEnsurePractice: (() async -> Void)?
    var onPracticeToggle: (() async -> Void)?
    var practiceSnapshot: (() async -> OverlaySnapshot)?
    var kitchenIsHot: (() -> Bool)?

    let model: SetupModel
    private var poll: Timer?
    private var keyMonitor: Any?
    var hotkey: Hotkey = .standard
    private var lastSize: CGSize = .zero
    private var talkButton: NSButton?

    init(flow: SetupFlow) {
        self.model = SetupModel(flow: flow)
        let panel = NotchPanel()
        super.init(window: panel)
        panel.delegate = self
        let root = SetupView(
            model: model,
            onPrimary: { [weak self] in await self?.handlePrimary() },
            onSecondary: { [weak self] in self?.openAccessibility?() },
            onSkip: { [weak self] in self?.skip() },
            onPractice: { [weak self] in await self?.handleTalk() },
            onPhaseChange: { [weak self] in self?.relayout(animated: true) }
        )
        let host = NSHostingController(rootView: root)
        host.sizingOptions = []
        host.view.appearance = NSAppearance(named: .darkAqua)
        let wrap = FirstMouseView(frame: NSRect(x: 0, y: 0, width: 400, height: 220))
        wrap.wantsLayer = true
        wrap.layer?.backgroundColor = NSColor(calibratedRed: 0.23, green: 0.15, blue: 0.10, alpha: 1).cgColor
        host.view.frame = wrap.bounds
        host.view.autoresizingMask = [.width, .height]
        wrap.addSubview(host.view)
        let talk = NSButton(title: "Click to talk", target: nil, action: nil)
        talk.bezelStyle = .rounded
        talk.font = .systemFont(ofSize: 13, weight: .semibold)
        talk.autoresizingMask = [.width, .minYMargin]
        wrap.addSubview(talk)
        panel.contentView = wrap
        talk.target = self
        talk.action = #selector(talkClicked)
        self.talkButton = talk
        layoutTalkButton()
    }

    @objc private func talkClicked() {
        tapasLog("talkClicked phase=\(model.flow.phase)")
        Task { await handleTalk() }
    }

    private func layoutTalkButton() {
        guard let wrap = window?.contentView, let talk = talkButton else { return }
        let inset: CGFloat = 16
        let height: CGFloat = 32
        talk.frame = NSRect(
            x: inset,
            y: 12,
            width: max(120, wrap.bounds.width - inset * 2),
            height: height
        )
        talk.title = model.listening ? "Listening…" : "Click to talk"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    var flow: SetupFlow {
        get { model.flow }
        set { model.flow = newValue }
    }

    func show() {
        guard let panel = window else { return }
        let collapsed = NotchGeometry.frame(size: CGSize(width: 200, height: 36), on: NotchGeometry.screen())
        panel.setFrame(collapsed, display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        relayout(animated: false)
        DispatchQueue.main.async { [weak self] in
            self?.relayout(animated: true)
        }
        startPolling()
        watchKeys()
        if !model.flow.modelsReady {
            Task { await runDownload() }
        }
    }

    private func watchKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53, model.flow.phase != .tryIt {
                skip()
                return nil
            }
            return event
        }
    }

    func handleTalk() async {
        let hot = kitchenIsHot?() == true
        tapasLog("handleTalk mic=\(model.flow.microphoneGranted) hot=\(hot)")
        model.busy = true
        model.flow.modelError = nil
        defer {
            model.busy = false
            layoutTalkButton()
            tapasLog("handleTalk done listening=\(model.listening) error=\(model.flow.modelError ?? "none")")
        }
        if !model.flow.microphoneGranted {
            model.flow.microphoneGranted = await allowMicrophone?() ?? false
            if !model.flow.microphoneGranted {
                model.flow.modelError = "Microphone is off."
                return
            }
        }
        if kitchenIsHot?() != true {
            talkButton?.title = "Starting…"
            model.flow.modelError = "Hiring the kitchen."
            await onEnsurePractice?()
        }
        if kitchenIsHot?() != true {
            model.flow.modelError = model.flow.modelError ?? "Kitchen isn't ready yet."
            return
        }
        model.flow.modelError = nil
        if model.flow.phase != .tryIt, model.flow.phase != .finished {
            model.flow.phase = .tryIt
            relayout(animated: true)
        }
        await onPracticeToggle?()
        if let snap = await practiceSnapshot?() {
            model.listening = snap.isVisible && snap.message == nil
            model.rms = snap.rms
            if let message = snap.message, !message.isEmpty {
                model.flow.modelError = message
            }
            if !snap.committedText.isEmpty {
                model.practiceText = snap.committedText
            }
        }
    }

    func relayout(animated: Bool) {
        guard let panel = window else { return }
        let screen = NotchGeometry.screen()
        let inset = NotchGeometry.topObscured(screen)
        if model.topInset != inset {
            model.topInset = inset
        }
        let content = sizeForPhase()
        let size = CGSize(width: content.width, height: content.height + inset)
        let rect = NotchGeometry.frame(size: size, on: screen)
        if animated, lastSize != .zero, lastSize != size {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.28
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(rect, display: true)
            }
        } else {
            panel.setFrame(rect, display: true)
        }
        lastSize = size
        layoutTalkButton()
    }

    private func sizeForPhase() -> CGSize {
        let detail = model.flow.detail?.isEmpty == false
        let neck: CGFloat = model.topInset > 0 ? 8 : 0
        switch model.flow.phase {
        case .peek:
            return CGSize(width: 400, height: 208 + neck)
        case .microphone:
            return CGSize(width: 360, height: (detail ? 90 : 72) + neck)
        case .accessibility:
            return CGSize(width: 380, height: (detail ? 90 : 72) + neck)
        case .kitchen:
            return CGSize(width: 360, height: 128 + neck)
        case .tryIt:
            return CGSize(width: 400, height: 220 + neck)
        case .finished:
            return CGSize(width: 320, height: 72 + neck)
        }
    }

    private func startPolling() {
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.tick()
            }
        }
    }

    private func tick() async {
        if let pollAccessibility {
            let state = pollAccessibility()
            model.flow.accessibilityTrusted = state.trusted
            model.flow.tapStarted = state.tapStarted
        }
        if let modelsReady {
            model.flow.modelsReady = await modelsReady()
            if let downloadFraction {
                model.flow.downloadFraction = await downloadFraction()
            }
        }
        if model.flow.phase == .kitchen, model.flow.modelsReady, !model.downloading {
            model.flow.advance()
            relayout(animated: true)
        }
        if model.flow.phase == .tryIt {
            if let snap = await practiceSnapshot?() {
                model.listening = snap.isVisible && snap.message == nil
                model.rms = snap.rms
                if let message = snap.message, !message.isEmpty {
                    model.flow.modelError = message
                }
                if !snap.committedText.isEmpty {
                    model.practiceText = snap.committedText
                    model.flow.modelError = nil
                }
            }
        }
        relayout(animated: false)
    }

    private func handlePrimary() async {
        switch model.flow.phase {
        case .peek:
            model.flow.advance()
            relayout(animated: true)
        case .microphone:
            if !model.flow.microphoneGranted {
                model.flow.microphoneGranted = await allowMicrophone?() ?? false
                if !model.flow.microphoneGranted {
                    model.flow.modelError = "Still off. Privacy & Security → Microphone."
                    relayout(animated: true)
                    return
                }
            }
            model.flow.modelError = nil
            model.flow.advance()
            relayout(animated: true)
        case .accessibility:
            model.flow.advance()
            relayout(animated: true)
        case .kitchen:
            if !model.flow.modelsReady {
                await runDownload()
                return
            }
            model.flow.advance()
            relayout(animated: true)
        case .tryIt, .finished:
            finish()
        }
    }

    private func runDownload() async {
        if model.flow.modelsReady { return }
        if model.downloading {
            while model.downloading, !model.flow.modelsReady {
                try? await Task.sleep(for: .milliseconds(80))
            }
            return
        }
        model.downloading = true
        do {
            try await downloadModels?()
            model.flow.modelsReady = true
            model.flow.downloadFraction = 1
            model.flow.modelError = nil
        } catch {
            model.flow.modelError = "Check the network and try again."
        }
        model.downloading = false
    }

    private func skip() {
        if model.flow.microphoneGranted, model.flow.modelsReady {
            finish()
        } else {
            teardown()
            window?.close()
        }
    }

    private func finish() {
        teardown()
        window?.close()
        onFinished?()
    }

    private func teardown() {
        poll?.invalidate()
        poll = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        teardown()
        onDismissed?()
    }
}

final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 36),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovableByWindowBackground = false
        isOpaque = true
        backgroundColor = NSColor(calibratedRed: 0.23, green: 0.15, blue: 0.10, alpha: 1)
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        animationBehavior = .none
        ignoresMouseEvents = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class FirstMouseView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var isOpaque: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) ?? self
    }
}

enum NotchGeometry {
    static func screen() -> NSScreen {
        let notched = NSScreen.screens.first { hasNotch($0) }
        return notched ?? NSScreen.main ?? NSScreen.screens[0]
    }

    static func hasNotch(_ screen: NSScreen) -> Bool {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else {
            return false
        }
        return right.minX > left.maxX + 40
    }

    static func topObscured(_ screen: NSScreen) -> CGFloat {
        guard hasNotch(screen) else { return 0 }
        return max(screen.safeAreaInsets.top, screen.auxiliaryTopLeftArea?.height ?? 0, 36)
    }

    static func anchor(_ screen: NSScreen) -> CGRect {
        let frame = screen.frame
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, right.minX > left.maxX + 40 {
            let width = right.minX - left.maxX
            let height = max(left.height, 28)
            return CGRect(x: left.maxX, y: frame.maxY - height, width: width, height: height)
        }
        return CGRect(x: frame.midX - 100, y: screen.visibleFrame.maxY - 28, width: 200, height: 28)
    }

    static func frame(size: CGSize, on screen: NSScreen) -> CGRect {
        let notch = anchor(screen)
        let x = notch.midX - size.width / 2
        let top = hasNotch(screen) ? screen.frame.maxY : screen.visibleFrame.maxY
        let y = top - size.height
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
