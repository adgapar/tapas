import AppKit
@preconcurrency import ApplicationServices
import Foundation
import TapasCore

@MainActor
func promptAccessibilityTrust() {
    // Register the running copy before opening Settings, which may contain an older build.
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
}

/// AX first. Fallback preserves every clipboard representation, not just plain text.
@MainActor
final class RoutingPaster: TextPaster {
    var practiceMode = false
    var target: NSRunningApplication?
    var onPractice: ((String) -> Void)?

    func paste(_ text: String) async throws {
        if practiceMode { onPractice?(text); return }
        guard AXIsProcessTrusted() else { throw AccessibilityDenied() }
        guard let target, !target.isTerminated,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
            throw PasteFailure.destinationChanged
        }
        if insert(text, into: target.processIdentifier) { return }
        let board = NSPasteboard.general
        let oldItems = (board.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
        board.clearContents()
        let wroteText = board.setString(text, forType: .string)
        let ownChange = board.changeCount
        defer {
            // A new user copy wins; otherwise restore rich text, images, files, etc.
            if board.changeCount == ownChange {
                board.clearContents()
                let restored = oldItems.map { values in
                    let item = NSPasteboardItem()
                    for (type, data) in values { item.setData(data, forType: type) }
                    return item
                }
                board.writeObjects(restored)
            }
        }
        guard wroteText else { throw PasteFailure.clipboardUnavailable }
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            throw PasteFailure.clipboardUnavailable
        }
        down.flags = .maskCommand; up.flags = .maskCommand
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(250))
    }

    private func insert(_ text: String, into pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        let element = unsafeDowncast(focused, to: AXUIElement.self)
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
    }
}

enum PasteFailure: Error { case destinationChanged, clipboardUnavailable }
