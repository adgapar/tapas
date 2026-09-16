import AppKit
import SwiftUI

@MainActor
final class PlateWindowController: NSWindowController, NSWindowDelegate {
    private var onResign: () -> Void = {}
    static let size = NSSize(width: 710, height: 770)
    init(model: PlateModel, actions: PlateActions, actaController: ActaController? = nil) {
        let window = FloatingWindow(contentRect: NSRect(origin: .zero, size: Self.size),
                                    styleMask: [.borderless, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Tapas"
        configureFloatingWindow(window)
        window.contentViewController = NSHostingController(rootView: FittedSurface(width: Self.size.width, height: Self.size.height) {
            PlateView(model: model, actions: actions, actaController: actaController)
        })
        super.init(window: window)
        onResign = actions.cancelShortcutRecording
        window.delegate = self
    }
    @available(*, unavailable) required init?(coder: NSCoder) { nil }
    func windowDidResignKey(_ notification: Notification) { onResign() }
    func windowWillClose(_ notification: Notification) { onResign() }
    func show() {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        placeFloatingWindow(window, preferred: Self.size)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
