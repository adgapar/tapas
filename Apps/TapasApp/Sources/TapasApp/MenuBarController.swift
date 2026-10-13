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
        item.button?.image = Self.templateMark()
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.setAccessibilityLabel("tapas — Small tools. Good company.")
    }
    var isShown: Bool { home.window?.isKeyWindow == true }
    func showHome() {
        onOpen?()
        let anchor = item.button.flatMap { button in button.window.map { $0.convertToScreen(button.convert(button.bounds, to: nil)) } }
        home.show(anchor: anchor)
    }

    /// A one-colour pintxo for the menu bar; macOS tints template images for light and dark bars.
    static func templateMark() -> NSImage {
        let image = NSImage(size: NSSize(width: 14, height: 18), flipped: true) { rect in
            let context = NSGraphicsContext.current?.cgContext
            context?.translateBy(x: rect.midX, y: rect.midY)
            context?.rotate(by: -19 * .pi / 180)
            context?.scaleBy(x: 0.118, y: 0.118)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: -1.6, y: -73, width: 3.2, height: 146), xRadius: 1.6, yRadius: 1.6).fill()
            for (i, width) in [53.0, 67, 53, 38].enumerated() {
                let y = Double(i) * 29 - 54
                let radius = i == 0 ? 12.0 : 4
                NSBezierPath(roundedRect: NSRect(x: -width / 2, y: y, width: width, height: 24), xRadius: radius, yRadius: radius).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
    @objc private func toggle() { if isShown { close() } else { showHome() } }
    func show() { showHome() }
    func close() { home.window?.orderOut(nil) }
    func update(_ snapshot: OverlaySnapshot, actaStatus: String? = nil) {
        let status = snapshot.phase == .idle ? (actaStatus ?? Grafico.tagline) : "Dictado · \(snapshot.phase.rawValue)"
        item.button?.toolTip = status
        item.button?.setAccessibilityLabel("tapas — \(status)")
    }
}
