import Foundation

public enum OverlayCopy {
    public static func message(for error: DictationError) -> String? {
        switch error {
        case .microphoneDenied:
            return "Microphone is off. Open System Settings to allow Tapas."
        case .accessibilityDenied:
            return "Turn Tapas on in Accessibility. I'll wait here."
        case .modelNotReady:
            return "Hiring the kitchen…"
        case .emptyClip:
            return "Too short. Talk, then press again."
        }
    }
}

public enum SetupGate {
    public static func message(trusted: Bool, tapStarted: Bool) -> String? {
        if tapStarted { return nil }
        if trusted {
            return "That's on. Quit Tapas from the menu bar and open it once more — macOS is picky."
        }
        return OverlayCopy.message(for: .accessibilityDenied)
    }
}

public struct TapasSettings: Equatable, Sendable {
    public var overlayEnabled: Bool
    public var historyDirectory: URL
    public var hotkey: Hotkey

    public init(
        overlayEnabled: Bool = false,
        historyDirectory: URL = Self.defaultHistoryDirectory,
        hotkey: Hotkey = .standard
    ) {
        self.overlayEnabled = overlayEnabled
        self.historyDirectory = historyDirectory
        self.hotkey = hotkey
    }

    public static var defaultHistoryDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/tapas/dictado", isDirectory: true)
    }
}
