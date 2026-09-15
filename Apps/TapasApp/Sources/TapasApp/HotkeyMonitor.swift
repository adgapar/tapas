import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import TapasCore

final class HotkeyMonitor: @unchecked Sendable {
    nonisolated(unsafe) static var shared: HotkeyMonitor?

    var onCancel: (@Sendable () -> Void)?
    var onTap: (@Sendable () -> Void)?
    var onRecorded: (@Sendable (Hotkey) -> Void)?
    var onRecordCancelled: (@Sendable () -> Void)?
    var recording = false

    var hotkey: Hotkey = .standard {
        didSet { tapper = HotkeyTapper(hotkey: hotkey) }
    }

    private var tapper = HotkeyTapper(hotkey: .standard)
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var localMonitor: Any?
    private var lastFire: TimeInterval = 0
    private var lastTapAttempt: TimeInterval?

    var tapRunning: Bool {
        guard let port, CFMachPortIsValid(port) else { return false }
        return CGEvent.tapIsEnabled(tap: port)
    }

    func installLocalMonitor() {
        HotkeyMonitor.shared = self
        if localMonitor != nil { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            if self?.tapRunning == false { self?.handleNSEvent(event) }
            return event
        }
    }

    @discardableResult
    func startTapIfTrusted() -> Bool {
        installLocalMonitor()
        guard AXIsProcessTrusted() else { return false }
        if let port, CFMachPortIsValid(port) {
            if !CGEvent.tapIsEnabled(tap: port) {
                tapper = HotkeyTapper(hotkey: hotkey)
                CGEvent.tapEnable(tap: port, enable: true)
            }
            if tapRunning { return true }
        }
        let now = ProcessInfo.processInfo.systemUptime
        if let lastTapAttempt, now - lastTapAttempt < 5 { return false }
        lastTapAttempt = now
        removeTap()
        tapper = HotkeyTapper(hotkey: hotkey)
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            // Use the Accessibility permission requested by setup. A listen-only tap
            // uses Input Monitoring authorization instead. Pass every event through.
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, _ in
                HotkeyMonitor.shared?.handle(type: type, event: event) ?? Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            tapasLog("global shortcut registration failed; will retry")
            return false
        }
        self.port = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tapasLog("global shortcut enabled=\(tapRunning)")
        return tapRunning
    }

    func noteTrustMayHaveChanged() {
        if AXIsProcessTrusted() {
            lastTapAttempt = nil
            _ = startTapIfTrusted()
        }
    }

    private func handleNSEvent(_ event: NSEvent) {
        let code = UInt16(event.keyCode)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiers = KeyModifiers.from(
            control: flags.contains(.control),
            option: flags.contains(.option),
            shift: flags.contains(.shift),
            command: flags.contains(.command)
        )
        let type: CGEventType
        switch event.type {
        case .keyDown: type = .keyDown
        case .keyUp: type = .keyUp
        case .flagsChanged: type = .flagsChanged
        default: return
        }
        _ = consider(type: type, code: code, modifiers: modifiers, isRepeat: event.type == .keyDown && event.isARepeat)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            tapper = HotkeyTapper(hotkey: hotkey)
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let modifiers = KeyModifiers.from(
            control: event.flags.contains(.maskControl),
            option: event.flags.contains(.maskAlternate),
            shift: event.flags.contains(.maskShift),
            command: event.flags.contains(.maskCommand)
        )
        _ = consider(type: type, code: code, modifiers: modifiers, isRepeat: isRepeat)
        return Unmanaged.passUnretained(event)
    }

    @discardableResult
    private func consider(type: CGEventType, code: UInt16, modifiers: KeyModifiers, isRepeat: Bool) -> Bool {
        if recording {
            if code == 53, type == .keyDown {
                recording = false
                onRecordCancelled?()
                return true
            }
            if let captured = capture(type: type, code: code, modifiers: modifiers) {
                recording = false
                onRecorded?(captured)
                return true
            }
            return false
        }

        if code == 53, type == .keyDown, !isRepeat { onCancel?(); return false }
        let toggled: Bool
        switch type {
        case .keyDown:
            toggled = tapper.handle(.down(code: code, isRepeat: isRepeat), modifiers: modifiers)
        case .keyUp:
            toggled = tapper.handle(.up(code: code), modifiers: modifiers)
        case .flagsChanged:
            toggled = tapper.handleFlags(code: code, modifiers: modifiers)
        default:
            return false
        }
        if toggled {
            fire()
        }
        return false
    }

    func stop() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        localMonitor = nil
        removeTap()
        lastTapAttempt = nil
    }

    private func removeTap() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let port { CFMachPortInvalidate(port) }
        source = nil; port = nil
    }

    private func fire() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastFire < 0.15 { return }
        lastFire = now
        onTap?()
    }

    private func capture(type: CGEventType, code: UInt16, modifiers: KeyModifiers) -> Hotkey? {
        if code == 54, type == .flagsChanged, modifiers.contains(.command) {
            return .rightCommand
        }
        if type == .flagsChanged, modifiers.rawValue.nonzeroBitCount >= 2 {
            return Hotkey(keyCode: nil, modifiers: modifiers)
        }
        if type == .keyDown, !Hotkey.isModifierKey(code), !modifiers.isEmpty {
            return Hotkey(keyCode: code, modifiers: modifiers)
        }
        return nil
    }
}
