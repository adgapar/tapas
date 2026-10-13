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

    /// Sample recordings in the real file format, so renders exercise first words, metadata and shapes.
    static func sampleLibrary() throws -> [HistoryEntry] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tapas-render-library", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let meeting = """
        ---
        schema_version: 1
        tool: acta
        duration_seconds: 3240
        languages: ["en", "es"]
        ---

        # Acta · Computer audio

        [00:00:10] **Microphone**: Hello team, sorry for being late. I think we have everyone?
        [00:00:18] **Computer audio**: No worries, we just started. Lea was walking us through the onboarding scope.
        [00:04:02] **Computer audio**: The proposal is three steps, and the folder choice moves into house rules.
        [00:11:40] **Microphone**: That works for me. Let’s keep the practice take, it is the moment people remember.
        [00:24:05] **Computer audio**: Agreed. Iñaki will share the new menu bar icon this week.
        [00:38:10] **Microphone**: Then I’ll draft the copy by Tuesday and we test it on Thursday.
        [00:51:30] **Computer audio**: Perfect. Gracias, everyone.
        """
        let take = """
        ---
        schema_version: 1
        tool: dictado
        duration_seconds: 52
        language: es
        ---

        Hola Ane, te paso el borrador con los cambios de la cláusula de fianza. Si te parece bien, lo firmamos el lunes.
        """
        let short = """
        ---
        schema_version: 1
        tool: dictado
        duration_seconds: 18
        language: en
        ---

        Move the save confirmation under the form so it stays visible after submit.
        """
        try meeting.write(to: root.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try take.write(to: root.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try short.write(to: root.appendingPathComponent("c.md"), atomically: true, encoding: .utf8)
        return try HistoryLibrary.read(directory: root)
    }

    static func renderViews(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let actions = PlateActions.inert
        let model = PlateModel()
        model.ready = true; model.microphoneGranted = true; model.accessibilityTrusted = true; model.shortcutRunning = true
        model.assistant.statuses = [.claude: "Installed", .codex: "Not installed", .cursor: "Not installed"]
        model.assistant.present = [.claude, .codex]
        // Onboarding: Arrive, Allow, First take, Acta, House rules.
        for stage in 0...4 {
            let setup = SetupModel(flow: SetupFlow(phase: .peek, microphoneGranted: stage != 1, accessibilityTrusted: stage > 1,
                                                   modelsReady: stage > 1, downloadFraction: 0.42))
            setup.stage = stage
            setup.downloading = stage < 2
            setup.preparationStatus = ModelPreparationStatus(model: "speech model", phase: .downloading, fraction: 0.42)
            try saveHosted(SetupView(model: setup, plate: model, actions: actions, onPrimary: {}, onSecondary: {}, onSkip: {}, onPractice: {},
                                     onCancel: {}, onHotkey: { _ in }, autoPrepare: false),
                           size: SetupWindowController.size, to: directory.appendingPathComponent("setup-\(stage).png"))
        }
        let practiced = SetupModel(flow: SetupFlow(phase: .tryIt, microphoneGranted: true, accessibilityTrusted: true, modelsReady: true))
        practiced.completedPractice = true
        practiced.practiceText = "Leave a little room for the good ideas, and send the draft to Ane on Monday."
        try saveHosted(SetupView(model: practiced, plate: model, actions: actions, onPrimary: {}, onSecondary: {}, onSkip: {}, onPractice: {},
                                 onCancel: {}, onHotkey: { _ in }, autoPrepare: false),
                       size: SetupWindowController.size, to: directory.appendingPathComponent("setup-2-practiced.png"))
        // The home card: what you kept, a recording, and house rules.
        model.entries = (try? sampleLibrary()) ?? []
        for tab in ["Recent", "Preferences"] {
            model.tab = tab
            try saveHosted(PlateView(model: model, actions: actions), size: model.preferredWindowSize, to: directory.appendingPathComponent("plate-\(tab.lowercased()).png"))
        }
        model.tab = "Recent"
        model.selected = model.entries.first
        try saveHosted(PlateView(model: model, actions: actions), size: model.preferredWindowSize, to: directory.appendingPathComponent("plate-detail.png"))
        model.selected = nil
        model.entries = []
        try saveHosted(PlateView(model: model, actions: actions), size: model.preferredWindowSize, to: directory.appendingPathComponent("plate-empty.png"))

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
            try saveHosted(DictadoOverlay(model: overlay, actions: actions).transaction { $0.animation = nil; $0.disablesAnimations = true }, size: DictadoMetrics.signal, to: directory.appendingPathComponent("dictado-\(phase.rawValue).png"))
        }
        overlay.snapshot.phase = .listening
        try saveHosted(DictadoCaption(model: overlay), size: DictadoMetrics.caption, to: directory.appendingPathComponent("dictado-caption.png"))
        try saveHosted(DictadoControls(model: overlay, actions: actions), size: DictadoMetrics.controls, to: directory.appendingPathComponent("dictado-controls.png"))
        let study = VStack(spacing: 4) {
            DictadoSignal(model: overlay, actions: actions)
            DictadoControls(model: overlay, actions: actions)
            DictadoCaption(model: overlay)
        }.padding(30).frame(width: 460, height: 260).background(Sobremesa.paperShade)
        try saveHosted(study.transaction { $0.animation = nil; $0.disablesAnimations = true }, size: NSSize(width: 460, height: 260), to: directory.appendingPathComponent("dictado-study.png"))
        // The pintxo forms, large, for review against the Sobremesa style sheet.
        let forms: [(String, PintxoForm, CGFloat, Double?)] = [("resting", .resting, 0, nil), ("filling", .resting, 0, 0.55),
                                                              ("standing", .standing(split: false), 0.7, nil), ("call", .standing(split: true), 0.8, nil),
                                                              ("working", .working, 0, nil)]
        for (name, form, level, progress) in forms {
            let view = SkewerPintxo(form: form, level: level, others: 0.05, progress: progress)
                .frame(width: 240, height: 240).background(Sobremesa.paper)
                .transaction { $0.animation = nil; $0.disablesAnimations = true }
            try saveHosted(view, size: NSSize(width: 240, height: 240), to: directory.appendingPathComponent("pintxo-\(name).png"))
        }
        overlay.snapshot = OverlaySnapshot(isVisible: true, committedText: "Nos vemos en la terraza a las seis.", message: "Paste wasn’t available. Copy your words or retry in the original app.", phase: .recovery, pasteFailed: true)
        try saveHosted(DictadoOverlay(model: overlay, actions: actions), size: NSSize(width: 384, height: 370), to: directory.appendingPathComponent("dictado-recovery.png"))
        overlay.snapshot = OverlaySnapshot(isVisible: true, message: "No words came through. Nothing saved. Try another take.", phase: .failed)
        try saveHosted(DictadoOverlay(model: overlay, actions: actions), size: NSSize(width: 384, height: 250), to: directory.appendingPathComponent("dictado-no-speech.png"))
    }
    #endif
}
