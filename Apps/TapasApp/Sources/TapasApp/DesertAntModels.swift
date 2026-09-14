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
    func identify(samples: [Float], sampleRate: Double) async throws -> LanguageGuess {
        let ear = Ear()
        let detection = try await ear.identify(samples: samples, sampleRate: sampleRate)
        return LanguageGuess(language: detection.language, isReliable: detection.isReliable)
    }
}

struct UhmAnalyzer: FillerAnalyzer {
    func analyze(samples: [Float], sampleRate: Double) async throws -> [FillerSpan] {
        let uhm = Uhm()
        let result = try await uhm.analyze(samples: samples, sampleRate: Int(sampleRate))
        return result.fillers.map { FillerSpan(start: $0.start, end: $0.end) }
    }
}

struct DesertRedactor: TextRedactor {
    func redact(_ text: String) async throws -> String {
        let result = try await Redact().redaction(of: text)
        return result.redactedText
    }
}

actor DesertCatalog: ModelCatalog {
    private var fraction: Double = 0
    private var specialized = false

    var isDownloaded: Bool {
        Voz.isDownloaded() && Ear.isDownloaded() && Uhm.isDownloaded()
    }

    var isReady: Bool {
        isDownloaded && specialized
    }

    var downloadFraction: Double { fraction }

    func download() async throws {
        if !Ear.isDownloaded() {
            try await Ear().download { value in
                Task { await self.setFraction(value * 0.1) }
            }
        }
        if !Uhm.isDownloaded() {
            try await Uhm().download { value in
                Task { await self.setFraction(0.1 + value * 0.1) }
            }
        }
        if !Voz.isDownloaded() {
            try await Voz.download { progress in
                Task { await self.setFraction(0.2 + progress.fraction * 0.7) }
            }
        }
        fraction = 0.9
        _ = try await Task.detached {
            try await Voz()
        }.value
        specialized = true
        fraction = 1
    }

    private func setFraction(_ value: Double) {
        fraction = min(1, max(0, value))
    }
}

func makeVoz() async throws -> Voz {
    try await Voz()
}
