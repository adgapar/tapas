import AppKit
import SwiftUI
import TapasCore

@MainActor @Observable
final class OverlayModel {
    var snapshot = OverlaySnapshot()
    var shortcut = Hotkey.standard.label
    var notice: String?
}

struct DictadoOverlay: View {
    @Bindable var model: OverlayModel
    var actions: PlateActions
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                PintxoMark(phase: model.snapshot.phase).frame(width: 28, height: 40)
                Eyebrow(text: "Dictado / \(label)")
                Spacer()
                if model.snapshot.phase == .listening {
                    ProgressView(value: min(1, Double(model.snapshot.rms) * 8)).tint(Grafico.olive).frame(width: 70)
                }
            }
            if let notice = model.notice { Text(notice).font(.system(size: 11)).foregroundStyle(Grafico.olive) }
            if model.snapshot.phase == .recovery || model.snapshot.phase == .failed {
                ScrollView { ResultView(snapshot: model.snapshot, actions: actions) }.frame(maxHeight: 290)
                if model.snapshot.committedText.isEmpty { Button("Open setup", action: actions.setup).buttonStyle(.plain) }
            } else {
                Text(model.snapshot.phase == .finishing ? "Finishing your thought…" : model.snapshot.committedText.isEmpty ? "Go on. Your thought goes here." : model.snapshot.committedText)
                    .font(.system(size: 15)).lineSpacing(3).lineLimit(4).frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("\(model.shortcut) to finish").font(.system(size: 11)).foregroundStyle(Grafico.muted)
                    Spacer()
                    if model.snapshot.phase == .listening {
                        Button("Finish", action: actions.talk).buttonStyle(.plain)
                        Button("Esc · Cancel", action: actions.cancel).buttonStyle(.plain)
                    }
                }.font(.system(size: 12))
            }
        }
        .padding(20).frame(width: 440).foregroundStyle(Grafico.ink)
        .background(Grafico.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Grafico.ink, lineWidth: 1.5))
        .padding(4).preferredColorScheme(.light)
    }
    private var label: String {
        switch model.snapshot.phase {
        case .listening: "Listening"
        case .starting: "Starting"
        case .finishing: "Finishing"
        case .recovery: "Your words are kept"
        case .failed: "A little help"
        default: "Ready"
        }
    }
}

@MainActor
final class OverlayPanel: NSPanel {
    let model = OverlayModel()
    private var host: NSHostingController<DictadoOverlay>?
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    func configure(actions: PlateActions) {
        let controller = NSHostingController(rootView: DictadoOverlay(model: model, actions: actions))
        host = controller
        contentViewController = controller
    }
    func apply(_ snapshot: OverlaySnapshot) {
        if model.snapshot != snapshot { model.snapshot = snapshot }
        guard snapshot.isVisible else { orderOut(nil); return }
        let height: CGFloat = snapshot.phase == .recovery ? 405 : snapshot.phase == .failed ? 250 : 205
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = CGSize(width: 448, height: height)
        let rect = CGRect(x: visible.midX - size.width / 2, y: visible.minY + 48, width: size.width, height: size.height)
        if frame != rect { setFrame(rect, display: true) }
        if !isVisible { orderFrontRegardless() }
    }
}
