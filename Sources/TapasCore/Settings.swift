import Foundation

public enum OverlayCopy {
    public static func message(for error: DictationError) -> String? {
        switch error {
        case .microphoneDenied:
            return "Microphone is off. Open System Settings to allow Tapas."
        case .accessibilityDenied:
            return "Accessibility is off. Open System Settings so Tapas can paste."
        case .modelNotReady:
            return "Downloading Voz…"
        case .emptyClip:
            return nil
        }
    }
}

public struct TapasSettings: Equatable, Sendable {
    public var overlayEnabled: Bool
    public var historyDirectory: URL
    public var hotkeyKeyCode: UInt16

    public init(
        overlayEnabled: Bool = true,
        historyDirectory: URL = Self.defaultHistoryDirectory,
        hotkeyKeyCode: UInt16 = RightCommandTapper.rightCommand
    ) {
        self.overlayEnabled = overlayEnabled
        self.historyDirectory = historyDirectory
        self.hotkeyKeyCode = hotkeyKeyCode
    }

    public static var defaultHistoryDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/tapas/dictado", isDirectory: true)
    }
}
