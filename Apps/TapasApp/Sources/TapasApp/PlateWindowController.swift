import AppKit
import SwiftUI

/// The main entry point remains reachable through the Dock even when macOS
/// cannot fit our menu-bar item beside the camera notch.
@MainActor
final class PlateWindowController: NSWindowController {
    init(model: PlateModel, actions: PlateActions) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 410, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Tapas"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: PlateView(model: model, actions: actions))
        window.appearance = NSAppearance(named: .aqua)
        window.collectionBehavior = [.moveToActiveSpace]
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show() {
        guard let window else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        // Move to the display being used to open Tapas, including after an
        // external display was disconnected. Keep the title bar reachable.
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            let area = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: area.midX - window.frame.width / 2,
                                          y: max(area.minY, area.midY - window.frame.height / 2)))
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
