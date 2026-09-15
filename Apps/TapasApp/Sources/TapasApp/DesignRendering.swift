import AppKit
import SwiftUI
import TapasCore

/// Build-time icon export and deterministic native view renders. No capture, model loading or user data.
@MainActor
enum DesignRendering {
    static func save<V: View>(_ view: V, to url: URL, scale: CGFloat = 2) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: url)
    }

    static func exportIcon(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let side = CGFloat(points)
                let view = PintxoMark().padding(side * 0.12).frame(width: side, height: side)
                    .background(Grafico.paper, in: RoundedRectangle(cornerRadius: side * 0.22))
                try save(view, to: directory.appendingPathComponent("icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"), scale: CGFloat(scale))
            }
        }
    }

    #if DEBUG
    // Hosting in our own offscreen window renders AppKit-backed controls and scroll views too.
    static func saveHosted<V: View>(_ view: V, size: NSSize, to url: URL) throws {
        let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: -10000, y: -10000), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        window.contentView = host
        window.appearance = NSAppearance(named: .aqua)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw CocoaError(.fileWriteUnknown) }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url)
        window.close()
    }

    static func renderViews(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (i, phase) in [SetupPhase.peek, .microphone, .accessibility, .kitchen, .tryIt, .finished].enumerated() {
            let model = SetupModel(flow: SetupFlow(phase: phase, microphoneGranted: i > 1, modelsReady: i > 3, downloadFraction: 0.64))
            model.practiceText = i == 4 ? "A little more room for the good ideas." : ""
            model.completedPractice = i == 4
            try saveHosted(SetupView(model: model, onPrimary: {}, onSecondary: {}, onSkip: {}, onPractice: {}, onCancel: {}, onHotkey: { _ in }), size: NSSize(width: 680, height: 560), to: directory.appendingPathComponent("setup-\(i).png"))
        }
        let actions = PlateActions(talk: {}, setup: {}, setHotkey: { _ in }, recordHotkey: {}, preferencesChanged: {}, folder: {}, copy: { _ in }, export: { _ in }, dismiss: {}, retryPaste: {}, retrySave: {}, cancel: {}, quit: {})
        let model = PlateModel()
        model.ready = true; model.microphoneGranted = true; model.accessibilityTrusted = true; model.shortcutRunning = true
        for tab in ["Tools", "Recent", "Preferences"] {
            model.tab = tab
            try saveHosted(PlateView(model: model, actions: actions), size: NSSize(width: 410, height: 620), to: directory.appendingPathComponent("plate-\(tab.lowercased()).png"))
        }
        let overlay = OverlayModel()
        overlay.snapshot = OverlaySnapshot(isVisible: true, committedText: "A little less busy. A little more room for the good ideas.", rms: 0.08, phase: .listening)
        for phase in [DictationPhase.starting, .listening, .finishing, .delivered] {
            overlay.snapshot.phase = phase
            try saveHosted(DictadoOverlay(model: overlay, actions: actions).transaction { $0.animation = nil; $0.disablesAnimations = true }, size: NSSize(width: 124, height: 28), to: directory.appendingPathComponent("dictado-\(phase.rawValue).png"))
        }
        overlay.snapshot.phase = .listening
        try saveHosted(DictadoCaption(model: overlay), size: NSSize(width: 340, height: 62), to: directory.appendingPathComponent("dictado-caption.png"))
        try saveHosted(DictadoControls(model: overlay, actions: actions), size: NSSize(width: 190, height: 32), to: directory.appendingPathComponent("dictado-controls.png"))
        let study = VStack(spacing: 4) {
            DictadoSignal(model: overlay, actions: actions)
            DictadoControls(model: overlay, actions: actions)
            DictadoCaption(model: overlay).padding(.top, 4)
        }.padding(30).frame(width: 420, height: 210).background(Grafico.paper)
        try saveHosted(study.transaction { $0.animation = nil; $0.disablesAnimations = true }, size: NSSize(width: 420, height: 210), to: directory.appendingPathComponent("dictado-study.png"))
        overlay.snapshot = OverlaySnapshot(isVisible: true, committedText: "Nos vemos en la terraza a las seis.", message: "Paste wasn’t available. Copy your words or retry in the original app.", phase: .recovery, pasteFailed: true)
        try saveHosted(DictadoOverlay(model: overlay, actions: actions), size: NSSize(width: 384, height: 370), to: directory.appendingPathComponent("dictado-recovery.png"))
        overlay.snapshot = OverlaySnapshot(isVisible: true, message: "No words came through. Nothing saved. Try another take.", phase: .failed)
        try saveHosted(DictadoOverlay(model: overlay, actions: actions), size: NSSize(width: 384, height: 250), to: directory.appendingPathComponent("dictado-no-speech.png"))
    }
    #endif
}
