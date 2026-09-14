import AppKit
@preconcurrency import ApplicationServices
import Foundation
import TapasCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var session: DictationSession?
    private var warming = false
    private let paster = RoutingPaster()
    private var menu: MenuBarController?
    private var setup: SetupWindowController?
    private let overlay = OverlayPanel()
    private let hotkey = HotkeyMonitor()
    private let mic = MicRecorder()
    private let catalog = DesertCatalog()
    private var settings = TapasSettings()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.overlayEnabled = UserDefaults.standard.object(forKey: "overlayEnabled") as? Bool ?? false
        if let data = UserDefaults.standard.data(forKey: "hotkey"),
           let saved = try? JSONDecoder().decode(Hotkey.self, from: data) {
            settings.hotkey = saved
        }
        hotkey.hotkey = settings.hotkey
        hotkey.onTap = { [weak self] in
            Task { await self?.handleTalk() }
        }
        menu = MenuBarController(settings: settings)
        menu?.hotkeyLabel = { [weak self] in self?.settings.hotkey.label ?? Hotkey.standard.label }
        menu?.onQuit = { [weak self] in
            self?.timer?.invalidate()
        }
        menu?.onSetup = { [weak self] in
            Task { await self?.presentSetup() }
        }
        menu?.onPickHotkey = { [weak self] value in
            self?.applyHotkey(value)
        }
        menu?.onRecordHotkey = { [weak self] in
            self?.beginHotkeyRecord()
        }
        hotkey.onRecorded = { [weak self] value in
            Task { @MainActor in
                self?.applyHotkey(value)
                self?.overlay.apply(OverlaySnapshot())
            }
        }
        hotkey.onRecordCancelled = { [weak self] in
            Task { @MainActor in
                self?.overlay.apply(OverlaySnapshot())
            }
        }
        Task { await self.warmKitchen() }
        Task { await self.route() }
        hotkey.installLocalMonitor()
        tapasLog("launched trusted=\(AXIsProcessTrusted())")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { await presentSetup() }
        return true
    }

    private func applyHotkey(_ value: Hotkey) {
        settings.hotkey = value
        hotkey.hotkey = value
        hotkey.recording = false
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: "hotkey")
        }
        setup?.hotkey = value
        setup?.model.flow.hotkeyLabel = value.label
        menu?.refreshHistory()
    }

    private func beginHotkeyRecord() {
        hotkey.recording = true
        hotkey.installLocalMonitor()
        overlay.apply(
            OverlaySnapshot(
                isVisible: true,
                message: "Press a shortcut. Esc keeps \(settings.hotkey.label)."
            )
        )
    }

    private func route() async {
        await presentSetup()
    }

    private func presentSetup() async {
        if setup?.window?.isVisible == true {
            setup?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let micOK = await mic.isAuthorized
        let modelsOK = session != nil
        showSetup(
            microphoneGranted: micOK,
            accessibilityTrusted: AXIsProcessTrusted(),
            modelsReady: modelsOK
        )
    }

    private func showSetup(microphoneGranted: Bool, accessibilityTrusted: Bool, modelsReady: Bool) {
        setup?.window?.close()
        NSApp.setActivationPolicy(.regular)
        var flow = SetupFlow.start(
            microphoneGranted: microphoneGranted,
            accessibilityTrusted: accessibilityTrusted,
            modelsReady: modelsReady
        )
        if !UserDefaults.standard.bool(forKey: "setupComplete") {
            flow.phase = .peek
        }
        flow.hotkeyLabel = settings.hotkey.label
        let controller = SetupWindowController(flow: flow)
        controller.hotkey = settings.hotkey
        controller.allowMicrophone = { [mic] in
            await mic.requestAuthorization()
        }
        controller.openAccessibility = {
            promptAccessibilityTrust()
        }
        controller.pollAccessibility = {
            let trusted = AXIsProcessTrusted()
            return (trusted, trusted)
        }
        controller.downloadModels = { [weak self] in
            await self?.warmKitchen()
            if self?.session == nil {
                throw CancellationError()
            }
        }
        controller.downloadFraction = { [weak self] in
            if self?.session != nil { return 1 }
            return await self?.catalog.downloadFraction ?? 0
        }
        controller.modelsReady = { [weak self] in
            self?.session != nil
        }
        controller.kitchenIsHot = { [weak self] in
            self?.session != nil
        }
        controller.onEnsurePractice = { [weak self] in
            await self?.warmKitchen()
        }
        controller.onPracticeToggle = { [weak self] in
            guard let session = self?.session else {
                self?.setup?.model.flow.modelError = "Kitchen isn't ready yet."
                tapasLog("toggle skipped, session nil")
                return
            }
            self?.paster.practiceMode = self?.setup?.window?.isVisible == true
            tapasLog("toggle")
            await session.toggle()
        }
        controller.practiceSnapshot = { [weak self] in
            await self?.session?.snapshot() ?? OverlaySnapshot()
        }
        controller.onDismissed = { [weak self] in
            self?.paster.practiceMode = false
            Task { await self?.session?.silence() }
            self?.overlay.apply(OverlaySnapshot())
            if !UserDefaults.standard.bool(forKey: "setupComplete") {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        controller.onFinished = { [weak self] in
            UserDefaults.standard.set(true, forKey: "setupComplete")
            NSApp.setActivationPolicy(.accessory)
            self?.paster.practiceMode = false
            Task { await self?.warmKitchen() }
        }
        paster.onPractice = { [weak controller] text in
            Task { @MainActor in
                controller?.model.practiceText = text
            }
        }
        setup = controller
        controller.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleTalk() async {
        if setup?.window?.isVisible == true {
            await setup?.handleTalk()
            return
        }
        await warmKitchen()
        paster.practiceMode = false
        await session?.toggle()
    }

    private func warmKitchen() async {
        if session != nil { return }
        if warming {
            while session == nil, warming {
                try? await Task.sleep(for: .milliseconds(80))
            }
            return
        }
        warming = true
        defer { warming = false }
        tapasLog("warm start")
        do {
            try await catalog.download()
            tapasLog("warm voz…")
            let voz = try await Task.detached {
                try await makeVoz()
            }.value
            tapasLog("warm voz ok")
            let dir = settings.historyDirectory
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let created = DictationSession(
                pipeline: TranscriptionPipeline(
                    recognizer: VozRecognizer(voz: voz),
                    ear: EarDetector(),
                    fillers: UhmAnalyzer()
                ),
                paster: paster,
                history: HistoryWriter(directory: dir, redactor: DesertRedactor()),
                models: catalog,
                microphone: mic
            )
            session = created
            mic.onSamples = { samples in
                Task { await created.ingest(samples: samples, sampleRate: 16_000) }
            }
            startOverlayTimer()
            tapasLog("warm ready")
        } catch {
            tapasLog("warm failed \(error)")
            setup?.model.flow.modelError = "The kitchen didn't make it."
        }
    }

    private func startOverlayTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let session = self.session else { return }
                var snap = await session.snapshot()
                if self.setup?.window?.isVisible == true {
                    snap.isVisible = false
                }
                let overlayOn = UserDefaults.standard.object(forKey: "overlayEnabled") as? Bool ?? false
                if !overlayOn {
                    snap.isVisible = false
                }
                self.overlay.apply(snap)
                if !snap.isVisible {
                    self.menu?.refreshHistory()
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}

final class RoutingPaster: TextPaster, @unchecked Sendable {
    var practiceMode = true
    var onPractice: (@Sendable (String) -> Void)?
    private let live = AccessibilityPaster()

    func paste(_ text: String) async throws {
        if practiceMode {
            onPractice?(text)
            return
        }
        try await live.paste(text)
    }
}
