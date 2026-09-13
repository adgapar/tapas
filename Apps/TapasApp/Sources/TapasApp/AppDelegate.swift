import AppKit
@preconcurrency import ApplicationServices
import Foundation
import TapasCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var session: DictationSession?
    private var menu: MenuBarController?
    private let overlay = OverlayPanel()
    private let hotkey = HotkeyMonitor()
    private let mic = MicRecorder()
    private let catalog = DesertCatalog()
    private var settings = TapasSettings()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.overlayEnabled = UserDefaults.standard.object(forKey: "overlayEnabled") as? Bool ?? true
        menu = MenuBarController(settings: settings)
        menu?.onQuit = { [weak self] in
            self?.timer?.invalidate()
        }
        Task { await self.boot() }
    }

    private func boot() async {
        do {
            if !(await catalog.isReady) {
                overlay.apply(
                    OverlaySnapshot(
                        isVisible: true,
                        message: OverlayCopy.message(for: .modelNotReady(fraction: 0)),
                        downloadFraction: 0
                    )
                )
                try await catalog.download()
            }
            let voz = try await makeVoz()
            let pipeline = TranscriptionPipeline(
                recognizer: VozRecognizer(voz: voz),
                ear: EarDetector(),
                fillers: UhmAnalyzer()
            )
            let session = DictationSession(
                pipeline: pipeline,
                paster: AccessibilityPaster(),
                history: HistoryWriter(directory: settings.historyDirectory, redactor: DesertRedactor()),
                models: catalog,
                microphone: mic
            )
            self.session = session
            mic.onSamples = { samples in
                Task { await session.ingest(samples: samples, sampleRate: 16_000) }
            }
            hotkey.onTap = {
                Task { await session.toggle() }
            }
            let trusted = AXIsProcessTrusted()
            if !trusted || !hotkey.start() {
                overlay.apply(
                    OverlaySnapshot(
                        isVisible: true,
                        message: OverlayCopy.message(for: .accessibilityDenied)
                    )
                )
                promptAccessibility()
                return
            }
            overlay.apply(OverlaySnapshot())
            startOverlayTimer()
        } catch {
            overlay.apply(
                OverlaySnapshot(
                    isVisible: true,
                    message: "Could not load Voz. Check the network and try again."
                )
            )
        }
    }

    private func startOverlayTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let session = self.session else { return }
            Task { @MainActor in
                var snap = await session.snapshot()
                let overlayOn = UserDefaults.standard.object(forKey: "overlayEnabled") as? Bool ?? true
                if !overlayOn {
                    snap.isVisible = snap.message != nil
                }
                self.overlay.apply(snap)
                if !snap.isVisible {
                    self.menu?.refreshHistory()
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func promptAccessibility() {
        promptAccessibilityTrust()
    }
}
