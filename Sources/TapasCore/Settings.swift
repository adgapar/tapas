import Foundation

public enum OverlayCopy {
    public static func message(for error: DictationError) -> String? {
        switch error {
        case .microphoneDenied:
            return "Microphone is off. Open System Settings to allow Tapas."
        case .accessibilityDenied:
            return "Allow Tapas in Accessibility to paste into your app. Your words are kept."
        case .modelNotReady:
            return "Prepare the voice models in Setup to start Dictado."
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
    public var historyEnabled: Bool
    public var meetingPromptsEnabled: Bool
    public var historyDirectory: URL
    public var actaHotkey: Hotkey
    public var hotkey: Hotkey

    public init(
        overlayEnabled: Bool = true,
        historyEnabled: Bool = true,
        meetingPromptsEnabled: Bool = true,
        historyDirectory: URL = Self.defaultHistoryDirectory,
        actaHotkey: Hotkey = .actaStandard,
        hotkey: Hotkey = .standard
    ) {
        self.overlayEnabled = overlayEnabled
        self.historyEnabled = historyEnabled
        self.meetingPromptsEnabled = meetingPromptsEnabled
        self.historyDirectory = historyDirectory
        self.actaHotkey = actaHotkey
        self.hotkey = hotkey
    }

    public var transcriptDirectory: URL {
        get { historyDirectory.deletingLastPathComponent() }
        set { historyDirectory = newValue.appendingPathComponent("dictado", isDirectory: true) }
    }

    public var actaDirectory: URL { transcriptDirectory.appendingPathComponent("acta", isDirectory: true) }

    public static var defaultHistoryDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/tapas/dictado", isDirectory: true)
    }
}
