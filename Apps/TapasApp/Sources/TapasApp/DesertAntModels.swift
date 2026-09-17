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
    private var preparationStep = 0
    private(set) var preparationStatus = ModelPreparationStatus()

    // Disk validation is deliberately restricted to preparation, never the hotkey path.
    var isDownloaded: Bool {
        Voz.isDownloaded() && Ear.isDownloaded() && Uhm.isDownloaded() && redactor.isDownloaded()
    }
    var isReady: Bool { prepared }
    var downloadFraction: Double { fraction }

    func download() async throws {
        if prepared { return }
        fraction = 0
        // These calls load the cached models too; the same instances are reused for each take.
        let earStep = beginPreparation("language detection")
        try await ear.download { value in Task { await self.report(value, step: earStep, base: 0, weight: 0.1) } }
        let uhmStep = beginPreparation("filler detection")
        try await uhm.download { value in Task { await self.report(value, step: uhmStep, base: 0.1, weight: 0.1) } }
        let vozStep = beginPreparation("speech recognition")
        try await Voz.download { progress in Task { await self.report(progress.fraction, step: vozStep, base: 0.2, weight: 0.7) } }
        let redactStep = beginPreparation("text privacy")
        try await redactor.download { value in Task { await self.report(value, step: redactStep, base: 0.9, weight: 0.08) } }
        beginPreparation("speech recognition")
        preparationStatus.phase = .preparing
        fraction = 0.98
        prepared = true
    }

    @discardableResult
    private func beginPreparation(_ model: String) -> Int {
        preparationStep += 1
        preparationStatus = ModelPreparationStatus(model: model)
        stepFraction = 0
        return preparationStep
    }

    private var stepFraction: Double = 0

    private func report(_ value: Double, step: Int, base: Double, weight: Double) {
        // Callback Tasks can arrive after the next model starts, or out of order.
        guard step == preparationStep, value >= stepFraction else { return }
        stepFraction = value
        fraction = min(0.98, max(fraction, base + value * weight))
        // The SDK reports 1 while it builds the local runtime, after downloading.
        let downloading = value < 1
        if downloading != (preparationStatus.fraction != nil) {
            preparationStatus.startedAt = Date()
        }
        preparationStatus.fraction = downloading ? value : nil
        preparationStatus.phase = downloading ? .downloading : .preparing
    }
}

func makeVoz() async throws -> Voz {
    try await Voz()
}
