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
    // Hosting renders AppKit-backed controls and scroll views. cacheDisplay omits
    // projective layer transforms; use the SwiftUI perspective exports for their geometry.
    static func saveHosted<V: View>(_ view: V, size: NSSize, to url: URL) throws {
        let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: -10000, y: -10000), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        window.contentView = host
        window.appearance = NSAppearance(named: .aqua)
        host.layoutSubtreeIfNeeded()
        window.orderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(1.1))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw CocoaError(.fileWriteUnknown) }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url)
        window.close()
    }

    static func renderServingMotion(to directory: URL) throws {
        let model = SetupModel(flow: SetupFlow(phase: .peek))
        model.entered = true; model.isPresented = true
        let size = SetupWindowController.size
        let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: -10000, y: -10000), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let view = SetupView(model: model, onPrimary: {}, onSecondary: {}, onSkip: {}, onPractice: {}, onCancel: {}, onHotkey: { _ in })
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        window.contentView = host
        window.appearance = NSAppearance(named: .aqua)
        window.orderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        model.stage = 1
        let start = Date()
        for milliseconds in [100, 240, 450, 700, 1100] {
            RunLoop.current.run(until: start.addingTimeInterval(Double(milliseconds) / 1000))
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw CocoaError(.fileWriteUnknown) }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: directory.appendingPathComponent("setup-serving-\(milliseconds).png"))
        }
    }

    static func renderViews(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (i, phase) in [SetupPhase.peek, .microphone, .accessibility, .kitchen, .tryIt, .finished].enumerated() {
            let model = SetupModel(flow: SetupFlow(phase: phase, microphoneGranted: i > 1, modelsReady: i > 3, downloadFraction: 0.64))
            model.practiceText = i == 4 ? "A little more room for the good ideas." : ""
            model.completedPractice = i == 4
            try saveHosted(SetupView(model: model, onPrimary: {}, onSecondary: {}, onSkip: {}, onPractice: {}, onCancel: {}, onHotkey: { _ in }), size: SetupWindowController.size, to: directory.appendingPathComponent("setup-\(i).png"))
        }
        let welcome = SetupModel(flow: SetupFlow(phase: .peek))
        welcome.entered = true
        try saveHosted(SetupView(model: welcome, onPrimary: {}, onSecondary: {}, onSkip: {}, onPractice: {}, onCancel: {}, onHotkey: { _ in }), size: SetupWindowController.size, to: directory.appendingPathComponent("setup-menu.png"))
        try save(SetupView(model: welcome, onPrimary: {}, onSecondary: {}, onSkip: {}, onPractice: {}, onCancel: {}, onHotkey: { _ in }, animateServing: false), to: directory.appendingPathComponent("setup-menu-perspective.png"), scale: 1)
        for stage in 0...3 {
            let small = SetupModel(flow: SetupFlow(phase: .peek, microphoneGranted: true, modelsReady: true))
            small.stage = stage; small.entered = true; small.accessibilityChecked = true
            small.folderConfirmed = true
            try save(SetupView(model: small, onPrimary: {}, onSecondary: {}, onSkip: {}, onPractice: {}, onCancel: {}, onHotkey: { _ in }, animateServing: false), to: directory.appendingPathComponent("setup-perspective-\(stage).png"), scale: 1)
            let surface = FittedSurface(width: SetupWindowController.size.width, height: SetupWindowController.size.height) {
                SetupView(model: small, onPrimary: {}, onSecondary: {}, onSkip: {}, onPractice: {}, onCancel: {}, onHotkey: { _ in })
            }
            try saveHosted(surface, size: NSSize(width: 704, height: 624), to: directory.appendingPathComponent("setup-small-\(stage).png"))
        }
        try renderServingMotion(to: directory)
        let actions = PlateActions(talk: {}, setup: {}, setHotkey: { _ in }, recordHotkey: {}, preferencesChanged: {}, folder: {}, copy: { _ in }, export: { _ in }, dismiss: {}, retryPaste: {}, retrySave: {}, cancel: {}, quit: {})
        let model = PlateModel()
        model.ready = true; model.microphoneGranted = true; model.accessibilityTrusted = true; model.shortcutRunning = true
        for tab in ["Tools", "Recent", "Preferences"] {
            model.tab = tab
            try saveHosted(PlateView(model: model, actions: actions), size: model.preferredWindowSize, to: directory.appendingPathComponent("plate-\(tab.lowercased()).png"))
        }
        try saveHosted(MeetingPromptView(appName: "Google Chrome", start: {}, dismiss: {}), size: NSSize(width: 400, height: 300), to: directory.appendingPathComponent("acta-suggestion.png"))
        let acta = ActaController()
        acta.model.ready = true
        acta.model.microphoneGranted = true
        acta.model.appAudioGranted = true
        try saveHosted(ActaView(model: acta.model, controller: acta), size: NSSize(width: 540, height: 650), to: directory.appendingPathComponent("acta-ready.png"))
        var meeting = ActaDocument(appName: "Computer audio")
        meeting.duration = 124
        meeting.segments = [
            ActaSegment(start: 8, source: .microphone, text: "Let’s leave a little room for the good ideas.", language: "en"),
            ActaSegment(start: 14, source: .systemAudio, text: "We can share a first draft on Friday.", language: "en")
        ]
        acta.model.snapshot.document = meeting
        acta.model.elapsed = 124
        acta.model.microphoneSeen = true; acta.model.appSeen = true
        acta.model.microphoneLevel = 0.32; acta.model.appLevel = 0.6
        for phase in [ActaPhase.recording, .paused, .recovery, .saved] {
            acta.model.snapshot.phase = phase
            acta.model.showingSavedReceipt = phase == .saved
            acta.model.canResume = phase == .paused
            acta.model.snapshot.message = phase == .recovery ? "The file couldn’t be saved. Your meeting is retained. Retry or export your words." : nil
            try saveHosted(ActaView(model: acta.model, controller: acta), size: NSSize(width: 540, height: 650), to: directory.appendingPathComponent("acta-\(phase.rawValue).png"))
        }
        acta.model.snapshot.savedURL = URL(fileURLWithPath: "/tmp/example-meeting.md")
        acta.model.showingSavedReceipt = true
        try saveHosted(ActaView(model: acta.model, controller: acta), size: NSSize(width: 540, height: 650), to: directory.appendingPathComponent("acta-complete.png"))
        acta.model.showingSavedReceipt = false
        try saveHosted(ActaView(model: acta.model, controller: acta), size: NSSize(width: 540, height: 760), to: directory.appendingPathComponent("acta-reopened.png"))
        model.tab = "Tools"
        model.selectedTool = "Acta"
        try saveHosted(PlateView(model: model, actions: actions, actaController: acta), size: PlateWindowController.size, to: directory.appendingPathComponent("home-acta-saved.png"))
        model.selectedTool = nil
        let compact = NSSize(width: 390, height: 440)
        try saveHosted(PlateWindowContent(model: model, actions: actions, actaController: acta), size: compact, to: directory.appendingPathComponent("home-small-display.png"))
        acta.model.snapshot.message = nil
        for phase in [ActaPhase.recording, .paused, .finishing, .recovery, .saved] {
            acta.model.snapshot.phase = phase
            acta.model.showingSavedReceipt = phase == .saved
            acta.model.canResume = phase == .paused
            acta.model.snapshot.message = phase == .recovery ? "Audio capture stopped. Your meeting is kept; open Acta to recover it." : nil
            acta.model.waveform = ActaWaveformHistory()
            for level in [0.0, 0.02, 0.1, 0.35, 0.7, 0.4, 0.15, 0.05, 0.0, 0.0, 0.1, 0.3,
                          0.6, 0.85, 0.5, 0.2, 0.05, 0.0, 0.15, 0.45, 0.7, 0.4, 0.2, 0.05] {
                acta.model.waveform.append(level)
            }
            try saveHosted(ActaCompanion(model: acta.model, controller: acta), size: acta.model.companionSize,
                           to: directory.appendingPathComponent("acta-companion-\(phase.rawValue).png"))
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
