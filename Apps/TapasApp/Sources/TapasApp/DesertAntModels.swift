import Ear
import Foundation
import Redact
import TapasCore
import Uhm
import Voz

actor VozRecognizer: SpeechRecognizer {
    private let voz: Voz

    init(voz: Voz) {
        self.voz = voz
    }

    func transcribe(samples: [Float], sampleRate: Double) async throws -> Transcript {
        let result = try await voz.transcribe(samples: samples, sampleRate: sampleRate)
        return Transcript(
            words: result.words.map { SpokenWord(text: $0.text, start: $0.start, end: $0.end) },
            duration: result.duration
        )
    }
}

struct EarDetector: SpokenLanguageDetector {
    let ear: Ear
    init(ear: Ear = Ear()) { self.ear = ear }
    func identify(samples: [Float], sampleRate: Double) async throws -> LanguageGuess {
        let detection = try await ear.identify(samples: samples, sampleRate: sampleRate)
        return LanguageGuess(language: detection.language, isReliable: detection.isReliable)
    }
}

struct UhmAnalyzer: FillerAnalyzer {
    let uhm: Uhm
    init(uhm: Uhm = Uhm()) { self.uhm = uhm }
    func analyze(samples: [Float], sampleRate: Double) async throws -> [FillerSpan] {
        let result = try await uhm.analyze(samples: samples, sampleRate: Int(sampleRate))
        return result.fillers.map { FillerSpan(start: $0.start, end: $0.end) }
    }
}

struct DesertRedactor: TextRedactor {
    let redactor: Redact
    init(redactor: Redact = Redact()) { self.redactor = redactor }
    func redact(_ text: String) async throws -> String {
        let result = try await redactor.redaction(of: text)
        return result.redactedText
    }
}

actor DesertCatalog: ModelCatalog {
    nonisolated let ear = Ear()
    nonisolated let uhm = Uhm()
    nonisolated let redactor = Redact()
    private var fraction: Double = 0
    private var prepared = false

    // Disk validation is deliberately restricted to preparation, never the hotkey path.
    var isDownloaded: Bool {
        Voz.isDownloaded() && Ear.isDownloaded() && Uhm.isDownloaded() && redactor.isDownloaded()
    }
    var isReady: Bool { prepared }
    var downloadFraction: Double { fraction }

    func download() async throws {
        if prepared { return }
        // These calls load the cached models too; the same instances are reused for each take.
        try await ear.download { value in Task { await self.setFraction(value * 0.1) } }
        try await uhm.download { value in Task { await self.setFraction(0.1 + value * 0.1) } }
        try await Voz.download { progress in Task { await self.setFraction(0.2 + progress.fraction * 0.7) } }
        try await redactor.download { value in Task { await self.setFraction(0.9 + value * 0.08) } }
        fraction = 0.98
        prepared = true
    }

    private func setFraction(_ value: Double) { fraction = min(0.98, max(fraction, value)) }
}

func makeVoz() async throws -> Voz {
    try await Voz()
}
