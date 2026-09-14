public enum SetupPhase: Equatable, Sendable {
    case peek
    case microphone
    case accessibility
    case kitchen
    case tryIt
    case finished
}

public struct SetupFlow: Equatable, Sendable {
    public var phase: SetupPhase
    public var microphoneGranted: Bool
    public var accessibilityTrusted: Bool
    public var tapStarted: Bool
    public var modelsReady: Bool
    public var downloadFraction: Double
    public var modelError: String?
    public var hotkeyLabel: String

    public init(
        phase: SetupPhase,
        microphoneGranted: Bool = false,
        accessibilityTrusted: Bool = false,
        tapStarted: Bool = false,
        modelsReady: Bool = false,
        downloadFraction: Double = 0,
        modelError: String? = nil,
        hotkeyLabel: String = Hotkey.standard.label
    ) {
        self.phase = phase
        self.microphoneGranted = microphoneGranted
        self.accessibilityTrusted = accessibilityTrusted
        self.tapStarted = tapStarted
        self.modelsReady = modelsReady
        self.downloadFraction = downloadFraction
        self.modelError = modelError
        self.hotkeyLabel = hotkeyLabel
    }

    public static func start(
        microphoneGranted: Bool,
        accessibilityTrusted: Bool,
        modelsReady: Bool
    ) -> SetupFlow {
        let phase: SetupPhase
        if !microphoneGranted && !accessibilityTrusted && !modelsReady {
            phase = .peek
        } else if !microphoneGranted {
            phase = .microphone
        } else if !accessibilityTrusted {
            phase = .accessibility
        } else if !modelsReady {
            phase = .kitchen
        } else {
            phase = .tryIt
        }
        return SetupFlow(
            phase: phase,
            microphoneGranted: microphoneGranted,
            accessibilityTrusted: accessibilityTrusted,
            tapStarted: false,
            modelsReady: modelsReady
        )
    }

    public var canContinue: Bool {
        switch phase {
        case .peek, .finished, .tryIt, .accessibility:
            return true
        case .microphone:
            return microphoneGranted
        case .kitchen:
            return modelsReady
        }
    }

    public var speech: String {
        switch phase {
        case .peek:
            return "Tapas"
        case .microphone:
            return "I need the mic."
        case .accessibility:
            return "One switch so I can paste."
        case .kitchen:
            if modelError != nil { return "The kitchen didn't make it." }
            if modelsReady { return "They're in." }
            return "Hiring the kitchen."
        case .tryIt:
            return "\(hotkeyLabel). Talk."
        case .finished:
            return "Same in any app."
        }
    }

    public var title: String { speech }

    public var body: String {
        switch phase {
        case .peek:
            return "A plate of small tools on this Mac. Not a chat, not a cloud.\n\nFirst dish is Dictado. You talk, it types where you are. Nothing leaves the machine. Notes land in Documents, so the tools you already use can read them."
        default:
            return speech
        }
    }

    public var detail: String? {
        if phase == .accessibility {
            return SetupGate.message(trusted: accessibilityTrusted, tapStarted: tapStarted)
        }
        return modelError
    }

    public var primaryTitle: String {
        switch phase {
        case .peek:
            return "Show me"
        case .microphone:
            return microphoneGranted ? "Next" : "Allow"
        case .accessibility:
            return accessibilityTrusted ? "Next" : "Later"
        case .kitchen:
            if modelsReady { return "Next" }
            if modelError != nil { return "Try again" }
            return ""
        case .tryIt:
            return "That's it"
        case .finished:
            return "Start"
        }
    }

    public var secondaryTitle: String? {
        if phase == .accessibility, !tapStarted {
            return "Open Settings"
        }
        return nil
    }

    public mutating func advance() {
        guard canContinue else { return }
        switch phase {
        case .peek:
            phase = microphoneGranted ? afterMic() : .microphone
        case .microphone:
            phase = afterMic()
        case .accessibility:
            phase = modelsReady ? .tryIt : .kitchen
        case .kitchen:
            phase = .tryIt
        case .tryIt:
            phase = .finished
        case .finished:
            break
        }
    }

    private func afterMic() -> SetupPhase {
        if !accessibilityTrusted { return .accessibility }
        if !modelsReady { return .kitchen }
        return .tryIt
    }
}
