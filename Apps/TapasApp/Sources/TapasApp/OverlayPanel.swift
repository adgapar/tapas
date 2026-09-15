import AppKit
import SwiftUI
import TapasCore

// Explicitly select the property wrapper on SDKs that also export a State macro.
private typealias StoredViewState<Value> = SwiftUI.State<Value>

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
    var label: String {
        switch snapshot.phase {
        case .starting: "Starting"
        case .listening: "Listening"
        case .finishing: "Finishing"
        case .delivered: "Listo ✓"
        default: "Dictado"
        }
    }
}

/// These are the same four ingredients throughout the transformation, in the same color order.
struct PintxoVoiceMark: View {
    var phase: DictationPhase
    var rms: Float
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StoredViewState private var spread = false
    private let widths: [CGFloat] = [10, 14, 11, 8]
    private let positions: [CGFloat] = [-8, -3, 3, 8]
    private let colors = [Grafico.saffron, Grafico.cobalt, Grafico.paprika, Grafico.olive]

    private var level: CGFloat { reduceMotion ? 0.45 : min(1, CGFloat(sqrt(max(0, rms))) * 2.5) }
    var body: some View {
        ZStack {
            Capsule().fill(Grafico.card.opacity(0.7)).frame(width: 1, height: 23)
                .rotationEffect(.degrees(-18)).opacity(spread ? 0 : 1)
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: index == 0 ? 2 : 1)
                    .fill(colors[index]).frame(width: widths[index], height: 3)
                    .scaleEffect(x: spread ? 0.35 + level * 1.05 : 1)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
                    .rotationEffect(.degrees(spread ? 90 : -18))
                    .offset(x: spread ? CGFloat(index) * 6 - 9 : 0, y: spread ? 0 : positions[index])
            }
        }
        .frame(width: 28, height: 24)
        .onAppear { updateForm() }
        .onChange(of: phase) { _, _ in updateForm() }
        .onChange(of: reduceMotion) { _, _ in updateForm() }
        .accessibilityHidden(true)
    }
    private func updateForm() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.55)) { spread = phase == .listening }
    }
}

struct DictadoSignal: View {
    @Bindable var model: OverlayModel
    var actions: PlateActions
    @FocusState private var focused: Bool

    var body: some View {
        Button {
            if model.snapshot.phase == .listening { actions.talk() }
        } label: {
            HStack(spacing: 6) {
                PintxoVoiceMark(phase: model.snapshot.phase, rms: model.snapshot.rms)
                Text(model.label).font(.system(size: 10, weight: .semibold)).fixedSize()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).frame(width: 124, height: 28)
            .foregroundStyle(Grafico.card)
            .background(Grafico.ink, in: UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 10, bottomTrailingRadius: 10, topTrailingRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(focused ? Grafico.saffron : .clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focused($focused)
        .onChange(of: focused) { _, value in model.signalFocused = value }
        .help(model.snapshot.phase == .listening ? "\(model.shortcut) to finish · Esc to cancel" : model.label)
        .accessibilityLabel("Dictado: \(model.label)")
        .accessibilityHint(model.snapshot.phase == .listening ? "Press to finish. Escape cancels the take." : "")
        .accessibilityAction(named: "Finish take") { if model.snapshot.phase == .listening { actions.talk() } }
        .accessibilityAction(named: "Cancel take") { if model.snapshot.phase.isActive { actions.cancel() } }
    }
}

struct DictadoCaption: View {
    @Bindable var model: OverlayModel
    var body: some View {
        Text(model.caption).font(.system(size: 13)).lineSpacing(3)
            .lineLimit(2).truncationMode(.head)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).frame(width: 340, height: 62)
            .foregroundStyle(Grafico.ink)
            .background(Grafico.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Grafico.ink.opacity(0.16)))
            .accessibilityLabel("Live words: \(model.caption)")
    }
}

struct DictadoControls: View {
    @Bindable var model: OverlayModel
    var actions: PlateActions
    @FocusState private var focused: String?
    var body: some View {
        HStack(spacing: 14) {
            Button("Finish", action: actions.talk).focused($focused, equals: "finish")
            Rectangle().fill(Grafico.card.opacity(0.3)).frame(width: 1, height: 12)
            Button("Esc · Cancel", action: actions.cancel).focused($focused, equals: "cancel")
        }
        .font(.system(size: 11, weight: .medium)).buttonStyle(.plain)
        .foregroundStyle(Grafico.card).padding(.horizontal, 14).frame(width: 190, height: 32)
        .background(Grafico.ink, in: Capsule())
        .onChange(of: focused) { _, value in model.controlsFocused = value != nil }
    }
}

struct DictadoRecovery: View {
    @Bindable var model: OverlayModel
    var actions: PlateActions
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                PintxoMark().frame(width: 24, height: 36)
                Eyebrow(text: model.snapshot.phase == .recovery ? "Dictado / Your words are kept" : "Dictado / Another little take?")
            }
            if let notice = model.notice { Text(notice).font(.system(size: 11)).foregroundStyle(Grafico.olive) }
            ScrollView { ResultView(snapshot: model.snapshot, actions: actions) }
            if model.snapshot.committedText.isEmpty {
                HStack {
                    Button("Try another take", action: actions.talk).buttonStyle(GraficoButtonStyle())
                    Button("Open setup", action: actions.setup).buttonStyle(.plain).font(.system(size: 12))
                }
            }
        }
        .padding(18).frame(width: 384, height: model.snapshot.phase == .recovery ? 370 : 250)
        .foregroundStyle(Grafico.ink)
        .background(Grafico.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Grafico.ink, lineWidth: 1))
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
        let size = model.needsRecovery ? CGSize(width: 384, height: snapshot.phase == .recovery ? 370 : 250) : CGSize(width: 124, height: 28)
        place(self, size: size, on: screen)

        let mouse = NSEvent.mouseLocation
        let hovered = NSMouseInRect(mouse, frame, false) || (controlsPanel.isVisible && NSMouseInRect(mouse, controlsPanel.frame, false))
        if hovered || model.signalFocused || model.controlsFocused { controlsUntil = now + 0.3 }
        let showControls = snapshot.phase == .listening && now < controlsUntil
        if showControls { place(controlsPanel, size: CGSize(width: 190, height: 32), on: screen, offset: 32) }
        else { controlsPanel.orderOut(nil); model.controlsFocused = false }

        if model.showLiveWords && !model.caption.isEmpty && (snapshot.phase == .listening || snapshot.phase == .finishing) {
            place(captionPanel, size: CGSize(width: 340, height: 62), on: screen, offset: showControls ? 72 : 36)
        } else { captionPanel.orderOut(nil) }
    }

    private func place(_ panel: NSPanel, size: CGSize, on screen: NSScreen, offset: CGFloat = 0) {
        let rect = DictadoPlacement.frame(size: size, screen: screen.frame, visible: screen.visibleFrame, safeTopInset: screen.safeAreaInsets.top, offset: offset)
        if panel.frame != rect { panel.setFrame(rect, display: true) }
        // Never activate Tapas or request keyboard focus when a surface appears.
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}
