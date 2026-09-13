import AppKit
@preconcurrency import ApplicationServices
import Foundation
import TapasCore

func promptAccessibilityTrust() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
}

final class AppPasteboard: TapasCore.Pasteboard, @unchecked Sendable {
    var string: String? {
        get { NSPasteboard.general.string(forType: .string) }
        set {
            let board = NSPasteboard.general
            board.clearContents()
            if let newValue {
                board.setString(newValue, forType: .string)
            }
        }
    }
}

struct HIDCommandV: CommandV {
    func commandV() async throws {
        await MainActor.run {
            let source = CGEventSource(stateID: .hidSystemState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
            down?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            up?.flags = .maskCommand
            up?.post(tap: .cghidEventTap)
        }
        try await Task.sleep(for: .milliseconds(40))
    }
}

struct AccessibilityPaster: TextPaster {
    private let fallback = ClipboardPaster(board: AppPasteboard(), typer: HIDCommandV())

    func paste(_ text: String) async throws {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            throw AccessibilityDenied()
        }
        let inserted = await MainActor.run { Self.insert(text) }
        if !inserted {
            try await fallback.paste(text)
        }
    }

    @MainActor
    private static func insert(_ text: String) -> Bool {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
        guard status == .success, let focused else { return false }
        let element = unsafeBitCast(focused, to: AXUIElement.self)
        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        ) == .success
    }
}
