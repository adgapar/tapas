import AppKit
import TapasCore

final class OverlayPanel: NSPanel {
    private let textField = NSTextField(labelWithString: "")
    private let meter = NSView()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 72),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true

        let box = NSVisualEffectView(frame: contentView?.bounds ?? .zero)
        box.autoresizingMask = [.width, .height]
        box.material = .hudWindow
        box.state = .active
        box.wantsLayer = true
        box.layer?.cornerRadius = 12
        contentView = box

        meter.wantsLayer = true
        meter.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        meter.layer?.cornerRadius = 2
        box.addSubview(meter)

        textField.font = .systemFont(ofSize: 14)
        textField.textColor = .labelColor
        textField.lineBreakMode = .byTruncatingHead
        textField.maximumNumberOfLines = 2
        box.addSubview(textField)
    }

    func apply(_ snapshot: OverlaySnapshot) {
        if !snapshot.isVisible {
            orderOut(nil)
            return
        }
        let message = snapshot.message ?? snapshot.committedText
        textField.stringValue = message.isEmpty ? "Listening" : message
        let width = max(8, CGFloat(snapshot.rms) * 200)
        let bounds = contentView?.bounds ?? NSRect(x: 0, y: 0, width: 420, height: 72)
        meter.frame = NSRect(x: 16, y: 12, width: width, height: 6)
        textField.frame = NSRect(x: 16, y: 24, width: bounds.width - 32, height: 36)
        if !isVisible {
            if let screen = NSScreen.main {
                let frame = screen.visibleFrame
                setFrameOrigin(NSPoint(x: frame.midX - 210, y: frame.minY + 80))
            }
            orderFrontRegardless()
        }
    }
}
