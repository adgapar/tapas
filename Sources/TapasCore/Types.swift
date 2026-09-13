import Foundation

public struct SpokenWord: Sendable, Equatable {
    public var text: String
    public var start: TimeInterval
    public var end: TimeInterval

    public init(text: String, start: TimeInterval, end: TimeInterval) {
        self.text = text
        self.start = start
        self.end = end
    }
}

public struct Transcript: Sendable, Equatable {
    public var words: [SpokenWord]
    public var duration: TimeInterval

    public var text: String { words.map(\.text).joined(separator: " ") }

    public init(words: [SpokenWord], duration: TimeInterval) {
        self.words = words
        self.duration = duration
    }
}

public struct LanguageGuess: Sendable, Equatable {
    public var language: String?
    public var isReliable: Bool

    public init(language: String?, isReliable: Bool) {
        self.language = language
        self.isReliable = isReliable
    }
}

public struct FillerSpan: Sendable, Equatable {
    public var start: TimeInterval
    public var end: TimeInterval

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }
}

public enum Tapa: String, Sendable, Equatable {
    case dictado, captura, consulta, acta, job
}

public enum DictationError: Equatable, Sendable {
    case microphoneDenied
    case accessibilityDenied
    case modelNotReady(fraction: Double?)
    case emptyClip
}

public struct HistoryRecord: Sendable, Equatable {
    public var startedAt: Date
    public var language: String?
    public var duration: TimeInterval
    public var pastedText: String

    public init(startedAt: Date, language: String?, duration: TimeInterval, pastedText: String) {
        self.startedAt = startedAt
        self.language = language
        self.duration = duration
        self.pastedText = pastedText
    }
}

public protocol SpeechRecognizer: Sendable {
    func transcribe(samples: [Float], sampleRate: Double) async throws -> Transcript
}

public protocol SpokenLanguageDetector: Sendable {
    func identify(samples: [Float], sampleRate: Double) async throws -> LanguageGuess
}

public protocol FillerAnalyzer: Sendable {
    func analyze(samples: [Float], sampleRate: Double) async throws -> [FillerSpan]
}

public protocol TextRedactor: Sendable {
    func redact(_ text: String) async throws -> String
}

public protocol TextPaster: Sendable {
    func paste(_ text: String) async throws
}

public protocol Microphone: Sendable {
    var isAuthorized: Bool { get async }
    func start() async throws
    func stop() async -> [Float]
}

public protocol ModelCatalog: Sendable {
    var isReady: Bool { get async }
    var downloadFraction: Double { get async }
    func download() async throws
}
