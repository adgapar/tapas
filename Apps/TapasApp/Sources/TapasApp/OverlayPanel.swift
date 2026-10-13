import AppKit
import SwiftUI
import TapasCore

@MainActor @Observable
final class OverlayModel {
    var snapshot = OverlaySnapshot()
    var shortcut = Hotkey.standard.label
    var showLiveWords = true
    var notice: String?
    var signalFocused = false
    var controlsFocused = false

    var needsRecovery: Bool { snapshot.phase == .recovery || snapshot.phase == .failed }
    var caption: String {
        // Only the preview is shortened. The session retains the complete transcript.
        String(snapshot.committedText.split(whereSeparator: \.isWhitespace).suffix(10).joined(separator: " ").suffix(120))
    }
    /// The caption split so the newest few words can be marked as they arrive.
    var captionParts: (older: String, newest: String) {
        let words = caption.split(whereSeparator: \.isWhitespace)
        let cut = max(0, words.count - 3)
        return (words[..<cut].joined(separator: " "), words[cut...].joined(separator: " "))
    }
    var label: String {
        switch snapshot.phase {
        case .starting: "Starting"
        case .listening: "Listening"
        case .finishing: "Finishing"
        case .delivered: "Listo"
        default: "Dictado"
        }
    }
}

/// Fixed sizes. The signal never resizes during a take (BEHAVIORS.md, El borde).
/// Each size includes the printed shadow offset below and to the right.
enum DictadoMetrics {
    static let tab = CGSize(width: 152, height: 40)
    static let tabShadow = CGSize(width: 3, height: 4)
    static let signal = CGSize(width: tab.width + tabShadow.width, height: tab.height + tabShadow.height)
    static let controls = CGSize(width: 193, height: 37)
    static let caption = CGSize(width: 384, height: 81)
    static let controlsOffset: CGFloat = signal.height + 4
    static func captionOffset(controlsShown: Bool) -> CGFloat {
        controlsShown ? controlsOffset + controls.height + 4 : signal.height + 4
    }
}

/// Sobremesa Dictado signal: a printed ink tab hanging under the menu bar, with the
/// pintxo standing on its pick while you talk and the state label in Fraunces.
struct DictadoSignal: View {
    @Bindable var model: OverlayModel
    var actions: PlateActions
    @FocusState private var focused: Bool

    private var level: CGFloat {
        min(1, CGFloat(sqrt(max(0, model.snapshot.rms))) * 2.5)
    }

    var body: some View {
        Button {
            if model.snapshot.phase == .listening { actions.talk() }
        } label: {
            HStack(spacing: 8) {
                SkewerPintxo(form: model.snapshot.phase.pintxoForm, level: level, onInk: true)
                    .frame(width: 36, height: 36)
                Text(model.label).font(Sobremesa.display(15, weight: 500, italic: true)).fixedSize()
                Spacer(minLength: 0)
            }
            .padding(.leading, 6).padding(.trailing, 14)
            .frame(width: DictadoMetrics.tab.width, height: DictadoMetrics.tab.height)
            .foregroundStyle(Sobremesa.paperOnInk)
            .background(CutShape(tight: 5, round: 18, corner: .hanging).fill(Sobremesa.ink))
            .background(CutShape(tight: 5, round: 18, corner: .hanging).fill(Sobremesa.deepInk)
                .offset(DictadoMetrics.tabShadow))
            .overlay(CutShape(tight: 5, round: 18, corner: .hanging).inkBorder(focused ? Sobremesa.saffron : .clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focused($focused)
        .frame(width: DictadoMetrics.signal.width, height: DictadoMetrics.signal.height, alignment: .topLeading)
        .onChange(of: focused) { _, value in model.signalFocused = value }
        .help(model.snapshot.phase == .listening ? "\(model.shortcut) to finish · Esc to cancel" : model.label)
        .accessibilityLabel("Dictado: \(model.label)")
        .accessibilityHint(model.snapshot.phase == .listening ? "Press to finish. Escape cancels the take." : "")
        .accessibilityAction(named: "Finish take") { if model.snapshot.phase == .listening { actions.talk() } }
        .accessibilityAction(named: "Cancel take") { if model.snapshot.phase.isActive { actions.cancel() } }
    }
}

/// Live words in a printed paper card, set in Fraunces. The newest words are marked in saffron.
struct DictadoCaption: View {
    @Bindable var model: OverlayModel

    private var text: AttributedString {
        let parts = model.captionParts
        var older = AttributedString(parts.older.isEmpty ? "" : parts.older + " ")
        older.foregroundColor = Sobremesa.ink
        var newest = AttributedString(parts.newest)
        newest.backgroundColor = Sobremesa.saffronTint
        return older + newest
    }

    var body: some View {
        let card = CutShape(tight: 4, round: 20)
        Text(text).font(Sobremesa.display(18)).lineSpacing(2)
            .lineLimit(2).truncationMode(.head)
            .foregroundStyle(Sobremesa.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .frame(width: DictadoMetrics.caption.width - 4, height: DictadoMetrics.caption.height - 5)
            .printed(card)
            .frame(width: DictadoMetrics.caption.width, height: DictadoMetrics.caption.height, alignment: .topLeading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Live words: \(model.caption)")
    }
}

struct DictadoControls: View {
    @Bindable var model: OverlayModel
    var actions: PlateActions
    @FocusState private var focused: String?
    var body: some View {
        let shape = CutShape(tight: 4, round: 14)
        HStack(spacing: 14) {
            Button("Finish", action: actions.talk).focused($focused, equals: "finish")
            Rectangle().fill(Sobremesa.paperOnInk.opacity(0.3)).frame(width: 1, height: 12)
            Button("Esc · Cancel", action: actions.cancel).focused($focused, equals: "cancel")
        }
        .font(.system(size: 11, weight: .semibold)).buttonStyle(.plain)
        .foregroundStyle(Sobremesa.paperOnInk)
        .frame(width: DictadoMetrics.controls.width - 3, height: DictadoMetrics.controls.height - 3)
        .printed(shape, fill: Sobremesa.ink, outline: nil, shadow: Sobremesa.deepInk, offset: CGSize(width: 2, height: 3))
        .frame(width: DictadoMetrics.controls.width, height: DictadoMetrics.controls.height, alignment: .topLeading)
        .onChange(of: focused) { _, value in model.controlsFocused = value != nil }
    }
}

struct DictadoRecovery: View {
    @Bindable var model: OverlayModel
    var actions: PlateActions
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SkewerPintxo(form: .resting).frame(width: 38, height: 38)
                Text(model.snapshot.phase == .recovery ? "Your words are kept." : "Another take?")
                    .font(Sobremesa.display(22, weight: 600))
            }
            if let notice = model.notice { Text(notice).font(.system(size: 12)).foregroundStyle(Sobremesa.muted) }
            ScrollView { ResultView(snapshot: model.snapshot, actions: actions) }
            if model.snapshot.committedText.isEmpty {
                HStack(spacing: 14) {
                    Button("Try another take", action: actions.talk).buttonStyle(.printed(.primary, small: true))
                    Button("Open setup", action: actions.setup).buttonStyle(.printed(.quiet, small: true))
                }
            }
        }
        .padding(18).frame(width: 376, height: (model.snapshot.phase == .recovery ? 370 : 250) - 8, alignment: .topLeading)
        .foregroundStyle(Sobremesa.ink)
        .printed(CutShape(tight: 5, round: 20), offset: CGSize(width: 4, height: 5))
        .frame(width: 384, height: model.snapshot.phase == .recovery ? 370 : 250, alignment: .topLeading)
        .preferredColorScheme(.light)
    }
}

struct DictadoOverlay: View {
    @Bindable var model: OverlayModel
    var actions: PlateActions
    var body: some View {
        if model.needsRecovery { DictadoRecovery(model: model, actions: actions) }
        else { DictadoSignal(model: model, actions: actions) }
    }
}

/// Separate windows keep the signal's hit area tiny and the caption transparent to clicks.
@MainActor
private final class OverlayAccessoryPanel: NSPanel {
    override var canBecomeKey: Bool { !ignoresMouseEvents }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayPanel: NSPanel {
    let model = OverlayModel()
    private let captionPanel = OverlayAccessoryPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let controlsPanel = OverlayAccessoryPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private var presentation = DictadoPresentation()
    private var screenNumber: NSNumber?
    private var controlsUntil: TimeInterval = 0

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        for panel in [self, captionPanel, controlsPanel] {
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isReleasedWhenClosed = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.animationBehavior = .none
        }
        captionPanel.ignoresMouseEvents = true
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func configure(actions: PlateActions) {
        let signal = NSHostingController(rootView: DictadoOverlay(model: model, actions: actions))
        let caption = NSHostingController(rootView: DictadoCaption(model: model))
        let controls = NSHostingController(rootView: DictadoControls(model: model, actions: actions))
        // Window geometry belongs to the panel, not changing SwiftUI content constraints.
        signal.sizingOptions = []; caption.sizingOptions = []; controls.sizingOptions = []
        contentViewController = signal
        captionPanel.contentViewController = caption
        controlsPanel.contentViewController = controls
    }

    func pinToCurrentScreen() {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        screenNumber = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    }

    func apply(_ snapshot: OverlaySnapshot, suppressed: Bool = false) {
        if model.snapshot != snapshot { model.snapshot = snapshot }
        let now = ProcessInfo.processInfo.systemUptime
        guard presentation.isVisible(for: snapshot, suppressed: suppressed, now: now) else {
            orderOut(nil); captionPanel.orderOut(nil); controlsPanel.orderOut(nil)
            model.signalFocused = false; model.controlsFocused = false
            controlsUntil = 0
            if snapshot.phase == .idle { screenNumber = nil }
            return
        }
        // Keep the take on its original display. Fall back only if that display disappears.
        if !NSScreen.screens.contains(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == screenNumber }) {
            pinToCurrentScreen()
        }
        guard let screen = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == screenNumber }) else { return }
        let size = model.needsRecovery ? CGSize(width: 384, height: snapshot.phase == .recovery ? 370 : 250) : DictadoMetrics.signal
        place(self, size: size, on: screen)

        let mouse = NSEvent.mouseLocation
        let hovered = NSMouseInRect(mouse, frame, false) || (controlsPanel.isVisible && NSMouseInRect(mouse, controlsPanel.frame, false))
        if hovered || model.signalFocused || model.controlsFocused { controlsUntil = now + 0.3 }
        let showControls = snapshot.phase == .listening && now < controlsUntil
        if showControls { place(controlsPanel, size: DictadoMetrics.controls, on: screen, offset: DictadoMetrics.controlsOffset) }
        else { controlsPanel.orderOut(nil); model.controlsFocused = false }

        if model.showLiveWords && !model.caption.isEmpty && (snapshot.phase == .listening || snapshot.phase == .finishing) {
            place(captionPanel, size: DictadoMetrics.caption, on: screen, offset: DictadoMetrics.captionOffset(controlsShown: showControls))
        } else { captionPanel.orderOut(nil) }
    }

    private func place(_ panel: NSPanel, size: CGSize, on screen: NSScreen, offset: CGFloat = 0) {
        let rect = DictadoPlacement.frame(size: size, screen: screen.frame, visible: screen.visibleFrame, safeTopInset: screen.safeAreaInsets.top, offset: offset)
        if panel.frame != rect { panel.setFrame(rect, display: true) }
        // Never activate Tapas or request keyboard focus when a surface appears.
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}
