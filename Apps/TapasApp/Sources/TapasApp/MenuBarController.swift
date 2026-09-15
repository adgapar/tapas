import AppKit
import SwiftUI
import TapasCore

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let home: PlateWindowController
    var onOpen: (() -> Void)?

    init(model: PlateModel, actions: PlateActions) {
        home = PlateWindowController(model: model, actions: actions)
        super.init()
        item.autosaveName = "TapasMainStatusItem"
        let renderer = ImageRenderer(content: PintxoMark().frame(width: 22, height: 22))
        renderer.scale = 2
        item.button?.image = renderer.nsImage
        item.button?.image?.isTemplate = false
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.setAccessibilityLabel("Tapas — Small tools. Good company.")
        popover.contentViewController = NSHostingController(rootView: PlateView(model: model, actions: actions))
        popover.behavior = .transient
        popover.delegate = self
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentSize = NSSize(width: 410, height: 620)
    }

    // A background home window must not suppress the recording indicator.
    var isShown: Bool { popover.isShown || home.window?.isKeyWindow == true }
    func showHome() {
        popover.performClose(nil)
        onOpen?()
        home.show()
    }
    @objc private func toggle() { if popover.isShown { close() } else { show() } }
    func show() {
        guard let button = item.button, button.window != nil else { showHome(); return }
        onOpen?()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
    func close() { popover.performClose(nil); home.window?.orderOut(nil) }
    func update(_ snapshot: OverlaySnapshot, actaStatus: String? = nil) {
        let status = snapshot.phase == .idle ? (actaStatus ?? Grafico.tagline) : "Dictado · \(snapshot.phase.rawValue)"
        item.button?.toolTip = status
        item.button?.setAccessibilityLabel("Tapas — \(status)")
    }
}
