import Foundation
import Testing
@testable import TapasCore

private actor ActaRecognizer: SpeechRecognizer {
    var failing = false
    var calls = 0
    func setFailing(_ value: Bool) { failing = value }
    func transcribe(samples: [Float], sampleRate: Double) async throws -> Transcript {
        calls += 1
        if failing { throw CocoaError(.fileReadUnknown) }
        return Transcript(words: [SpokenWord(text: samples.first! > 0.2 ? "Hello from the app." : "Hello from the microphone.", start: 0, end: 1)], duration: Double(samples.count) / sampleRate)
    }
}
private struct ActaLanguage: SpokenLanguageDetector {
    func identify(samples: [Float], sampleRate: Double) async throws -> LanguageGuess { LanguageGuess(language: "en", isReliable: true) }
}
private struct ActaFillers: FillerAnalyzer {
    func analyze(samples: [Float], sampleRate: Double) async throws -> [FillerSpan] { [] }
}
private struct ActaFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let recognizer = ActaRecognizer()
    var output: URL { root.appendingPathComponent("acta") }
    var recovery: URL { root.appendingPathComponent("recovery") }
    func makeSession() -> ActaSession {
        ActaSession(pipeline: TranscriptionPipeline(recognizer: recognizer, ear: ActaLanguage(), fillers: ActaFillers()), recoveryRoot: recovery, outputDirectory: output)
    }
    func cleanup() { try? FileManager.default.removeItem(at: root) }
}

@Test func actaSavesBothSourcesAndExcludesPausedAudio() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let session = fixture.makeSession()
    try await session.start(appName: "Meeting app")
    await session.ingest(samples: Array(repeating: 0.1, count: 16_000), source: .microphone, start: 0)
    await session.pause(duration: 2, note: "Paused for Dictado.")
    await session.ingest(samples: Array(repeating: 0.3, count: 16_000), source: .app, start: 90)
    try await session.resume()
    await session.ingest(samples: Array(repeating: 0.3, count: 16_000), source: .app, start: 2)
    await session.pause(duration: 4)
    await session.finish()
    let state = await session.snapshot()
    #expect(state.phase == .saved)
    #expect(state.document?.duration == 4)
    #expect(state.document?.segments.count == 2)
    let text = try String(contentsOf: #require(state.savedURL), encoding: .utf8)
    #expect(text.contains("[00:00:00] **Microphone**"))
    #expect(text.contains("[00:00:02] **App audio**"))
    #expect(text.contains("languages: [\"en\"]"))
    #expect(text.contains("Paused for Dictado."))
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.recovery.path).isEmpty)
    #expect(try HistoryLibrary.read(directory: fixture.output).count == 1)
}

@Test func actaRetriesOutputFailureWithoutDuplicatingSegmentsOrFiles() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let session = fixture.makeSession()
    try await session.start(appName: "Meet")
    try Data("blocked".utf8).write(to: fixture.output)
    await session.ingest(samples: Array(repeating: 0.1, count: 1000), source: .microphone, start: 0)
    await session.pause(duration: 1)
    await session.finish()
    #expect(await session.snapshot().phase == .recovery)
    #expect(await session.snapshot().document?.segments.count == 1)
    try FileManager.default.removeItem(at: fixture.output)
    await session.finish()
    await session.finish()
    #expect(await session.snapshot().phase == .saved)
    #expect(await fixture.recognizer.calls == 1)
    #expect(try HistoryLibrary.read(directory: fixture.output).count == 1)
}

@Test func actaRestoresPendingAudioAndTranscriptAfterRestart() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let first = fixture.makeSession()
    try await first.start(appName: "Zoom")
    await fixture.recognizer.setFailing(true)
    await first.ingest(samples: Array(repeating: 0.3, count: 16_000), source: .app, start: 6)
    await first.pause(duration: 7)
    await first.finish()
    #expect(await first.snapshot().phase == .recovery)
    #expect(await first.snapshot().pendingChunks == 1)
    let restored = fixture.makeSession()
    try await restored.recover()
    #expect(await restored.snapshot().phase == .paused)
    #expect(await restored.snapshot().document?.appName == "Zoom")
    await fixture.recognizer.setFailing(false)
    await restored.finish()
    let result = await restored.snapshot()
    #expect(result.phase == .saved)
    #expect(result.document?.segments.count == 1)
    #expect(result.document?.segments.first?.start == 6)
    #expect(result.document?.duration == 7)
}

@Test func computerAudioSurvivesRecoveryAndKeepsLegacyAppLabels() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let first = fixture.makeSession()
    try await first.start(appName: "Computer audio")
    await fixture.recognizer.setFailing(true)
    await first.ingest(samples: Array(repeating: 0.3, count: 16_000), source: .systemAudio, start: 6)
    await first.pause(duration: 7)
    await first.finish()
    #expect(await first.snapshot().pendingChunks == 1)
    let restored = fixture.makeSession()
    try await restored.recover()
    await fixture.recognizer.setFailing(false)
    await restored.finish()
    let result = await restored.snapshot()
    #expect(result.phase == .saved)
    #expect(result.document?.segments.first?.source == .systemAudio)
    let text = try String(contentsOf: #require(result.savedURL), encoding: .utf8)
    #expect(text.contains("[00:00:06] **Computer audio**"))
    let legacy = try JSONDecoder().decode(ActaSource.self, from: Data("\"app\"".utf8))
    #expect(legacy.label == "App audio")
}

@Test func actaRestoresRecognizedTextAfterFailedSave() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let first = fixture.makeSession()
    try await first.start(appName: "Teams")
    try Data().write(to: fixture.output)
    await first.ingest(samples: Array(repeating: 0.1, count: 1000), source: .microphone, start: 0)
    await first.pause(duration: 1)
    await first.finish()
    let restored = fixture.makeSession()
    try await restored.recover()
    #expect(await restored.snapshot().document?.segments.count == 1)
    try FileManager.default.removeItem(at: fixture.output)
    await restored.finish()
    #expect(await restored.snapshot().phase == .saved)
    #expect(await fixture.recognizer.calls == 1)
}

@Test func actaQuietMeetingGetsExplicitNoSpeechFile() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let session = fixture.makeSession()
    try await session.start(appName: "Silent app")
    await session.ingest(samples: Array(repeating: 0, count: 16_000), source: .app, start: 0)
    await session.pause(duration: 3)
    await session.finish()
    let state = await session.snapshot()
    #expect(state.document?.markdown.contains("No speech was recognized.") == true)
    #expect(state.document?.duration == 3)
    #expect(await fixture.recognizer.calls == 0)
}

@Test func actaNewMeetingCannotDiscardUnfinishedRecording() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let session = fixture.makeSession()
    try await session.start(appName: "First")
    let id = await session.snapshot().document?.id
    try await session.start(appName: "Second")
    try await session.newMeeting()
    #expect(await session.snapshot().document?.id == id)
    await session.pause(duration: 1)
    await session.finish()
    try await session.newMeeting()
    #expect(await session.snapshot().phase == .idle)
    try await session.start(appName: "Second")
    #expect(await session.snapshot().document?.id != id)
    await session.finish()
    #expect(try HistoryLibrary.read(directory: fixture.output).count == 2)
}

@Test func actaRestartSkipsAudioAlreadyCheckpointed() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let first = fixture.makeSession()
    try await first.start(appName: "Meet")
    try Data().write(to: fixture.output)
    await first.ingest(samples: Array(repeating: 0.1, count: 1000), source: .microphone, start: 0)
    await first.pause(duration: 1)
    await first.finish()
    let document = try #require(await first.snapshot().document)
    let chunkID = try #require(document.processedChunks.first)
    // Simulate a crash between checkpointing recognition and removing its audio.
    let orphan = fixture.recovery.appendingPathComponent(document.id.uuidString).appendingPathComponent("audio-orphan.json")
    let bytes = try JSONSerialization.data(withJSONObject: ["id": chunkID.uuidString, "source": "microphone", "start": 0, "samples": [0.1, 0.1]])
    try bytes.write(to: orphan)
    let restored = fixture.makeSession()
    try await restored.recover()
    try FileManager.default.removeItem(at: fixture.output)
    await restored.finish()
    #expect(await restored.snapshot().document?.segments.count == 1)
    #expect(await fixture.recognizer.calls == 1)
    #expect(await restored.snapshot().phase == .saved)
}

@Test func actaDiscardRemovesOnlyTheCurrentRecovery() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let session = fixture.makeSession()
    try await session.start(appName: "Meet")
    await session.pause(duration: 1)
    try await session.discard()
    #expect(await session.snapshot().phase == .idle)
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.recovery.path).isEmpty)
    #expect(!FileManager.default.fileExists(atPath: fixture.output.path))
}

@Test func actaCheckpointFailureRetainsAudioForRetry() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let session = fixture.makeSession()
    try await session.start(appName: "Meet")
    let id = try #require(await session.snapshot().document?.id)
    let checkpoint = fixture.recovery.appendingPathComponent(id.uuidString).appendingPathComponent("session.json")
    try FileManager.default.removeItem(at: checkpoint)
    try FileManager.default.createDirectory(at: checkpoint, withIntermediateDirectories: false)
    await session.ingest(samples: Array(repeating: 0.1, count: 1000), source: .microphone, start: 0)
    await session.pause(duration: 1)
    await session.finish()
    #expect(await session.snapshot().phase == .recovery)
    #expect(await session.snapshot().pendingChunks == 1)
    try FileManager.default.removeItem(at: checkpoint)
    await session.finish()
    #expect(await session.snapshot().phase == .saved)
    #expect(await session.snapshot().document?.segments.count == 1)
}

@Test func actaRecoveryRetainsOriginalFolderAfterPreferenceChange() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let first = fixture.makeSession()
    try await first.start(appName: "Meet")
    await first.pause(duration: 1)
    let next = fixture.root.appendingPathComponent("new-folder")
    await first.setOutputDirectory(next)
    // A restarted app has the new preference, but the checkpoint has the take's destination.
    let restored = fixture.makeSession()
    await restored.setOutputDirectory(next)
    try await restored.recover()
    await restored.finish()
    #expect(await restored.snapshot().savedURL?.deletingLastPathComponent().path == fixture.output.path)
    #expect(!FileManager.default.fileExists(atPath: next.path))
    try await restored.newMeeting()
    try await restored.start(appName: "Next")
    await restored.pause(duration: 1)
    await restored.finish()
    #expect(await restored.snapshot().savedURL?.deletingLastPathComponent().path == next.path)
}

@Test func oldActaCheckpointsWithoutFolderStillDecode() throws {
    let encoded = try JSONEncoder().encode(ActaDocument(appName: "Meet"))
    var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    json.removeValue(forKey: "outputDirectory")
    let document = try JSONDecoder().decode(ActaDocument.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(document.outputDirectory == nil)
    #expect(document.appName == "Meet")
}

@Test func legacyRecoveryKeepsTheOriginalDefaultDestination() async throws {
    let fixture = ActaFixture(); defer { fixture.cleanup() }
    let session = fixture.makeSession()
    try await session.start(appName: "Legacy")
    await session.pause(duration: 1)
    let document = try #require(await session.snapshot().document)
    let checkpoint = fixture.recovery.appendingPathComponent(document.id.uuidString).appendingPathComponent("session.json")
    var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: checkpoint)) as? [String: Any])
    json.removeValue(forKey: "outputDirectory")
    try JSONSerialization.data(withJSONObject: json).write(to: checkpoint)
    let restored = fixture.makeSession()
    await restored.setOutputDirectory(fixture.root.appendingPathComponent("new-preference"))
    try await restored.recover()
    #expect(await restored.snapshot().document?.outputDirectory == TapasSettings().actaDirectory)
}
