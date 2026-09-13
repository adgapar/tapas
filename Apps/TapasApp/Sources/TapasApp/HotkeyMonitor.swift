import ApplicationServices
import CoreGraphics
import Foundation
import TapasCore

final class HotkeyMonitor: @unchecked Sendable {
    nonisolated(unsafe) static var shared: HotkeyMonitor?

    var onTap: (@Sendable () -> Void)?
    private var tapper = RightCommandTapper()
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    func start() -> Bool {
        HotkeyMonitor.shared = self
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, _ in
                HotkeyMonitor.shared?.handle(type: type, event: event) ?? Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            return false
        }
        self.port = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let keyEvent: KeyEvent
        switch type {
        case .keyDown:
            keyEvent = .down(code: code, isRepeat: isRepeat)
        case .keyUp:
            keyEvent = .up(code: code)
        default:
            return Unmanaged.passUnretained(event)
        }
        let toggled = tapper.handle(keyEvent)
        if toggled {
            onTap?()
        }
        if code == RightCommandTapper.rightCommand {
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}
