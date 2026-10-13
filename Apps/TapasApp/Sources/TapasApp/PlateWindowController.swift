import AppKit
import SwiftUI

@MainActor
final class PlateWindowController: NSWindowController, NSWindowDelegate {
    private var onResign: () -> Void = {}
    /// The home card, plus room for its printed shadow. House rules use the same card.
    static let homeSize = NSSize(width: 540, height: 720)
    static let size = NSSize(width: 560, height: 780)
    private let model: PlateModel
    init(model: PlateModel, actions: PlateActions, actaController: ActaController? = nil) {
        self.model = model
        let window = FloatingWindow(contentRect: NSRect(origin: .zero, size: model.preferredWindowSize),
                                    styleMask: [.borderless, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "tapas"
        configureFloatingWindow(window)
        super.init(window: window)
        window.contentViewController = NSHostingController(rootView: PlateWindowContent(model: model, actions: actions, actaController: actaController, onResize: { [weak self] in self?.resizeForCurrentPage() }))
        onResign = actions.cancelShortcutRecording
        window.delegate = self
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
    func windowDidResignKey(_ notification: Notification) { onResign() }
    func windowWillClose(_ notification: Notification) { onResign() }
    func resizeForCurrentPage() {
        guard let window else { return }
        let preferred = model.preferredWindowSize
        let area = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        let scale = area.map { min(1, ($0.width - 32) / preferred.width, ($0.height - 32) / preferred.height) } ?? 1
        let size = NSSize(width: preferred.width * scale, height: preferred.height * scale)
        var origin = NSPoint(x: window.frame.midX - size.width / 2, y: window.frame.maxY - size.height)
        if let area {
            origin.x = min(max(origin.x, area.minX + 16), area.maxX - size.width - 16)
            origin.y = min(max(origin.y, area.minY + 16), area.maxY - size.height - 16)
        }
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
    /// Hangs the card below the menu bar pintxo when there is one; otherwise centres it.
    func show(anchor: NSRect? = nil) {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        placeFloatingWindow(window, preferred: model.preferredWindowSize)
        if let anchor, let area = (NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main)?.visibleFrame {
            let size = window.frame.size
            let x = min(max(anchor.maxX - size.width + 10, area.minX + 8), area.maxX - size.width - 8)
            window.setFrameOrigin(NSPoint(x: x, y: area.maxY - size.height - 4))
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Observe navigation inside SwiftUI so the hosting surface and native frame agree.
struct PlateWindowContent: View {
    @Bindable var model: PlateModel
    var actions: PlateActions
    var actaController: ActaController? = nil
    var onResize: () -> Void = {}
    var body: some View {
        let size = model.preferredWindowSize
        FittedSurface(width: size.width, height: size.height) {
            PlateView(model: model, actions: actions, actaController: actaController)
        }.onChange(of: size) { _, _ in onResize() }
    }
}
