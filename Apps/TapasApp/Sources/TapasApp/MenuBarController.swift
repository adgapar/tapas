import AppKit
import SwiftUI
import TapasCore

@MainActor
final class MenuBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let home: PlateWindowController
    var onOpen: (() -> Void)?
    init(model: PlateModel, actions: PlateActions, actaController: ActaController? = nil) {
        home = PlateWindowController(model: model, actions: actions, actaController: actaController)
        super.init()
        item.autosaveName = "TapasMainStatusItem"
        let renderer = ImageRenderer(content: PintxoMark().frame(width: 22, height: 22))
        renderer.scale = 2
        item.button?.image = renderer.nsImage
        item.button?.image?.isTemplate = false
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.setAccessibilityLabel("Tapas — Small tools. Good company.")
    }
    var isShown: Bool { home.window?.isKeyWindow == true }
    func showHome() { onOpen?(); home.show() }
    @objc private func toggle() { if isShown { close() } else { showHome() } }
    func show() { showHome() }
    func close() { home.window?.orderOut(nil) }
    func update(_ snapshot: OverlaySnapshot, actaStatus: String? = nil) {
        let status = snapshot.phase == .idle ? (actaStatus ?? Grafico.tagline) : "Dictado · \(snapshot.phase.rawValue)"
        item.button?.toolTip = status
        item.button?.setAccessibilityLabel("Tapas — \(status)")
    }
}
