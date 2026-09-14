import AppKit
import SwiftUI
import TapasCore

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    var onOpen: (() -> Void)?

    init(model: PlateModel, actions: PlateActions) {
        super.init()
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

    var isShown: Bool { popover.isShown }
    @objc private func toggle() { if popover.isShown { close() } else { show() } }
    func show() {
        guard let button = item.button else { return }
        onOpen?()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
    func close() { popover.performClose(nil) }
    func update(_ snapshot: OverlaySnapshot) {
        let title: String
        switch snapshot.phase {
        case .starting: title = " Starting"
        case .listening: title = " ● Dictado"
        case .finishing: title = " Finishing"
        case .recovery, .failed: title = " ! Dictado"
        default: title = ""
        }
        if item.button?.title != title { item.button?.title = title }
        item.button?.toolTip = snapshot.phase == .idle ? Grafico.tagline : "Dictado · \(snapshot.phase.rawValue)"
    }
}
