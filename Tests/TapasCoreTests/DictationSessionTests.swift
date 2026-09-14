import Foundation
import Testing
@testable import TapasCore

final class SpyPaster: TextPaster, @unchecked Sendable {
    var pasted: [String] = []
    func paste(_ text: String) async throws { pasted.append(text) }
}

final class FlagCatalog: ModelCatalog, @unchecked Sendable {
    var isReady: Bool
    var downloadFraction: Double
    init(isReady: Bool, downloadFraction: Double = 1) {
        self.isReady = isReady
        self.downloadFraction = downloadFraction
    }
    func download() async throws {}
}

final class FlagMic: Microphone, @unchecked Sendable {
    var isAuthorized: Bool
    var started = false
    init(isAuthorized: Bool) { self.isAuthorized = isAuthorized }
    func start() async throws { started = true }
    func stop() async -> [Float] { [] }
}

func sessionPipeline(text: String = "hello") -> TranscriptionPipeline {
    TranscriptionPipeline(
        recognizer: ScriptedRecognizer(words: [
            SpokenWord(text: text, start: 0, end: 1),
        ]),
        ear: ScriptedEar(guess: LanguageGuess(language: "en", isReliable: true)),
        fillers: ScriptedUhm(spans: [])
    )
}

func makeSession(
    text: String = "hello",
    ready: Bool = true,
    authorized: Bool = true,
    paster: SpyPaster,
    directory: URL
) -> DictationSession {
    DictationSession(
        pipeline: sessionPipeline(text: text),
        paster: paster,
        history: HistoryWriter(directory: directory, redactor: FakeRedactor()),
        models: FlagCatalog(isReady: ready),
        microphone: FlagMic(isAuthorized: authorized)
    )
}

func tempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

func loud() -> [Float] { [Float](repeating: 0.2, count: 320) }
func quiet() -> [Float] { [Float](repeating: 0, count: 320) }

@Test func toggleOnThenOffPastesFinalText() async throws {
    let paster = SpyPaster()
    let session = makeSession(paster: paster, directory: try tempDir())
    await session.toggle()
    for _ in 0..<10 { await session.ingest(samples: loud(), sampleRate: 16_000) }
    for _ in 0..<25 { await session.ingest(samples: quiet(), sampleRate: 16_000) }
    await session.toggle()
    #expect(paster.pasted == ["hello"])
    #expect(await session.snapshot().isVisible == false)
}

@Test func emptyClipPastesNothing() async throws {
    let paster = SpyPaster()
    let session = makeSession(paster: paster, directory: try tempDir())
    await session.toggle()
    for _ in 0..<5 { await session.ingest(samples: quiet(), sampleRate: 16_000) }
    await session.toggle()
    #expect(paster.pasted.isEmpty)
}

@Test func hotkeyIgnoredUntilModelReady() async throws {
    let paster = SpyPaster()
    let session = makeSession(ready: false, paster: paster, directory: try tempDir())
    await session.toggle()
    #expect(paster.pasted.isEmpty)
    #expect(await session.snapshot().message == "Hiring the kitchen…")
}

@Test func micDeniedShowsMessage() async throws {
    let paster = SpyPaster()
    let session = makeSession(authorized: false, paster: paster, directory: try tempDir())
    await session.toggle()
    #expect(paster.pasted.isEmpty)
    #expect(
        await session.snapshot().message
            == "Microphone is off. Open System Settings to allow Tapas."
    )
}

@Test func slowChunkKeepsCommittedText() async throws {
    let paster = SpyPaster()
    let session = makeSession(paster: paster, directory: try tempDir())
    await session.toggle()
    for _ in 0..<10 { await session.ingest(samples: loud(), sampleRate: 16_000) }
    for _ in 0..<25 { await session.ingest(samples: quiet(), sampleRate: 16_000) }
    #expect(await session.snapshot().committedText == "hello")
    for _ in 0..<10 { await session.ingest(samples: loud(), sampleRate: 16_000) }
    #expect(await session.snapshot().committedText == "hello")
}
