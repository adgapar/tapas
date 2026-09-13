public struct PipelineResult: Sendable, Equatable {
    public var transcript: Transcript
    public var language: String?

    public init(transcript: Transcript, language: String?) {
        self.transcript = transcript
        self.language = language
    }
}

public struct TranscriptionPipeline: Sendable {
    public var recognizer: any SpeechRecognizer
    public var ear: any SpokenLanguageDetector
    public var fillers: any FillerAnalyzer

    public init(recognizer: any SpeechRecognizer, ear: any SpokenLanguageDetector, fillers: any FillerAnalyzer) {
        self.recognizer = recognizer
        self.ear = ear
        self.fillers = fillers
    }

    public func chunk(samples: [Float], sampleRate: Double, lastLanguage: String?) async throws -> PipelineResult {
        let guess = try await ear.identify(samples: samples, sampleRate: sampleRate)
        let language = LanguagePolicy.resolve(guess: guess, lastKnown: lastLanguage)
        let transcript = try await recognizer.transcribe(samples: samples, sampleRate: sampleRate)
        return PipelineResult(transcript: transcript, language: language)
    }

    public func finish(samples: [Float], sampleRate: Double, lastLanguage: String?) async throws -> PipelineResult {
        var result = try await chunk(samples: samples, sampleRate: sampleRate, lastLanguage: lastLanguage)
        if result.language == "en" {
            let spans = try await fillers.analyze(samples: samples, sampleRate: sampleRate)
            result.transcript = FillerStripper.strip(
                transcript: result.transcript,
                fillers: spans,
                language: result.language
            )
        }
        return result
    }
}
