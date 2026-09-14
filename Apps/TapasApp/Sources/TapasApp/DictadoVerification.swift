#if DEBUG
import AppKit
import AVFoundation
import TapasCore

/// Opt-in developer smoke check using a supplied audio fixture, never the microphone.
@MainActor
enum DictadoVerification {
    static func run(audio: URL, historyDirectory: URL) async throws {
        let catalog = DesertCatalog()
        guard await catalog.isDownloaded else {
            throw VerificationError.modelsMissing
        }
        try await catalog.download()
        let file = try AVAudioFile(forReading: audio)
        guard let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: file.processingFormat, to: outputFormat) else { throw VerificationError.audioFormat }
        try file.read(into: input)
        let capacity = AVAudioFrameCount((Double(input.frameLength) * 16_000 / file.processingFormat.sampleRate).rounded(.up)) + 4096
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { throw VerificationError.audioFormat }
        var conversionError: NSError?
        var supplied = false
        converter.convert(to: output, error: &conversionError) { _, status in
            if supplied { status.pointee = .endOfStream; return nil }
            supplied = true; status.pointee = .haveData; return input
        }
        if let conversionError { throw conversionError }
        guard let channel = output.floatChannelData?[0] else { throw VerificationError.audioFormat }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
        let paster = FixturePaster()
        let voz = try await makeVoz()
        let session = DictationSession(
            pipeline: TranscriptionPipeline(recognizer: VozRecognizer(voz: voz), ear: EarDetector(ear: catalog.ear), fillers: UhmAnalyzer(uhm: catalog.uhm)),
            paster: paster, history: HistoryWriter(directory: historyDirectory, redactor: DesertRedactor(redactor: catalog.redactor)),
            models: catalog, microphone: FixtureMicrophone(samples: samples))
        await session.toggle()
        await session.toggle()
        let result = await session.snapshot()
        guard result.phase == .delivered, let historyURL = result.historyURL,
              !result.committedText.isEmpty, await paster.text == result.committedText else {
            throw VerificationError.delivery(result.message ?? "No result")
        }
        print("Transcript: \(result.committedText)")
        print("History: \(historyURL.path)")
        print("PASS: local audio → language/transcription/fillers → fixture paste → redacted Markdown")
    }
}

private actor FixturePaster: TextPaster {
    var text = ""
    func paste(_ text: String) async throws { self.text = text }
}
private struct FixtureMicrophone: Microphone {
    var samples: [Float]
    var isAuthorized: Bool { get async { true } }
    func start() async throws {}
    func stop() async -> [Float] { samples }
}
private enum VerificationError: Error {
    case modelsMissing, audioFormat, delivery(String)
}
#endif
