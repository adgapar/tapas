import Testing
@testable import TapasCore

struct ScriptedRecognizer: SpeechRecognizer {
    var words: [SpokenWord]
    func transcribe(samples: [Float], sampleRate: Double) async throws -> Transcript {
        Transcript(words: words, duration: words.last?.end ?? 0)
    }
}

struct ScriptedEar: SpokenLanguageDetector {
    var guess: LanguageGuess
    func identify(samples: [Float], sampleRate: Double) async throws -> LanguageGuess { guess }
}

struct ScriptedUhm: FillerAnalyzer {
    var spans: [FillerSpan]
    func analyze(samples: [Float], sampleRate: Double) async throws -> [FillerSpan] { spans }
}

@Test func chunkUsesEarThenVozWithoutUhm() async throws {
    let pipeline = TranscriptionPipeline(
        recognizer: ScriptedRecognizer(words: [
            SpokenWord(text: "um", start: 0, end: 0.3),
            SpokenWord(text: "hello", start: 0.4, end: 1),
        ]),
        ear: ScriptedEar(guess: LanguageGuess(language: "en", isReliable: true)),
        fillers: ScriptedUhm(spans: [FillerSpan(start: 0, end: 0.35)])
    )
    let result = try await pipeline.chunk(samples: [0.1], sampleRate: 16_000, lastLanguage: nil)
    #expect(result.transcript.text == "um hello")
    #expect(result.language == "en")
}

@Test func finishStripsEnglishFillers() async throws {
    let pipeline = TranscriptionPipeline(
        recognizer: ScriptedRecognizer(words: [
            SpokenWord(text: "um", start: 0, end: 1),
        ]),
        ear: ScriptedEar(guess: LanguageGuess(language: "en", isReliable: true)),
        fillers: ScriptedUhm(spans: [FillerSpan(start: 0, end: 1)])
    )
    let result = try await pipeline.finish(samples: [0.1], sampleRate: 16_000, lastLanguage: "en")
    #expect(result.transcript.words.isEmpty)
}
