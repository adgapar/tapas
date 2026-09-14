import Foundation
import Testing
@testable import TapasCore

actor RecoverablePaster: TextPaster {
    var fails = true
    var texts: [String] = []
    func allow() { fails = false }
    func paste(_ text: String) async throws {
        if fails { throw AccessibilityDenied() }
        texts.append(text)
    }
}

actor ControlledRecognizer: SpeechRecognizer {
    var continuation: CheckedContinuation<Transcript, Never>?
    var started = false
    func transcribe(samples: [Float], sampleRate: Double) async throws -> Transcript {
        started = true
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish() {
        continuation?.resume(returning: Transcript(words: [SpokenWord(text: "old take", start: 0, end: 1)], duration: 1))
        continuation = nil
    }
}

func capture(_ session: DictationSession) async {
    await session.toggle()
    await session.ingest(samples: Array(repeating: Float(0.2), count: 8_000), sampleRate: 16_000)
    await session.toggle()
}

@Test func deniedPasteKeepsWordsAndSavesHistoryThenRetriesWithoutDuplicate() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let paster = RecoverablePaster()
    let session = DictationSession(pipeline: sessionPipeline(), paster: paster,
        history: HistoryWriter(directory: dir, redactor: FakeRedactor()), models: FlagCatalog(isReady: true), microphone: FlagMic(isAuthorized: true))
    await capture(session)
    let failed = await session.snapshot()
    #expect(failed.phase == .recovery)
    #expect(failed.committedText == "hello")
    #expect(failed.pasteFailed)
    #expect(failed.historyURL != nil)
    await session.toggle()
    #expect(await session.snapshot() == failed)
    await paster.allow()
    await session.retryPaste()
    #expect(await session.snapshot().phase == .delivered)
    #expect(await paster.texts == ["hello"])
    #expect(try HistoryLibrary.read(directory: dir).count == 1)
}

@Test func saveFailureDoesNotPreventPasteAndCanBeRetried() async throws {
    let root = try tempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let blocked = root.appendingPathComponent("history")
    try Data("not a directory".utf8).write(to: blocked)
    let paster = SpyPaster()
    let session = makeSession(paster: paster, directory: blocked)
    await capture(session)
    #expect(paster.pasted == ["hello"])
    #expect(await session.snapshot().saveFailed)
    #expect(await session.snapshot().committedText == "hello")
    try FileManager.default.removeItem(at: blocked)
    await session.retrySave()
    await session.retrySave()
    #expect(await session.snapshot().phase == .delivered)
    #expect(try HistoryLibrary.read(directory: blocked).count == 1)
    #expect(paster.pasted == ["hello"])
}

@Test func historyDisabledStillPastesWithoutCreatingFiles() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let paster = SpyPaster()
    let session = makeSession(paster: paster, directory: dir)
    await session.setHistoryEnabled(false)
    await capture(session)
    #expect(paster.pasted == ["hello"])
    #expect(try HistoryLibrary.read(directory: dir).isEmpty)
    #expect(await session.snapshot().historyURL == nil)
}

@Test func historyPreferenceIsCapturedAtStartOfTake() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let session = makeSession(paster: SpyPaster(), directory: dir)
    await session.toggle()
    await session.setHistoryEnabled(false)
    await session.ingest(samples: Array(repeating: 0.2, count: 8_000), sampleRate: 16_000)
    await session.toggle()
    #expect(try HistoryLibrary.read(directory: dir).count == 1)
}

@Test func cancelledTakeDoesNotPasteOrSaveAndLateChunkCannotReviveIt() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let recognizer = ControlledRecognizer()
    let paster = SpyPaster()
    let session = DictationSession(pipeline: TranscriptionPipeline(recognizer: recognizer,
        ear: ScriptedEar(guess: LanguageGuess(language: "en", isReliable: true)), fillers: ScriptedUhm(spans: [])),
        paster: paster, history: HistoryWriter(directory: dir, redactor: FakeRedactor()),
        models: FlagCatalog(isReady: true), microphone: FlagMic(isAuthorized: true))
    await session.toggle()
    let ingest = Task { await session.ingest(samples: Array(repeating: 0.2, count: 20_000), sampleRate: 16_000) }
    while !(await recognizer.started) { await Task.yield() }
    await session.silence()
    await recognizer.finish()
    await ingest.value
    #expect(await session.snapshot().phase == .idle)
    #expect(await session.snapshot().committedText.isEmpty)
    #expect(paster.pasted.isEmpty)
    #expect(try HistoryLibrary.read(directory: dir).isEmpty)
}

@Test func concurrentHistoryWritesNeverOverwrite() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let writer = HistoryWriter(directory: dir, redactor: FakeRedactor())
    let date = Date()
    let urls = try await withThrowingTaskGroup(of: URL.self) { group in
        for i in 0..<10 {
            group.addTask { try await writer.write(HistoryRecord(startedAt: date, language: "en", duration: 1, pastedText: "take \(i)")) }
        }
        var values: [URL] = []
        for try await value in group { values.append(value) }
        return values
    }
    #expect(Set(urls).count == 10)
    #expect(try HistoryLibrary.read(directory: dir).count == 10)
}

@Test func libraryParsesFrontMatterAndKeepsBodyReadable() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    _ = try await HistoryWriter(directory: dir, redactor: FakeRedactor()).write(
        HistoryRecord(startedAt: Date(), language: "es", duration: 2, pastedText: "Nos vemos en la terraza.\nA las seis."))
    let entries = try HistoryLibrary.read(directory: dir)
    #expect(entries.count == 1)
    #expect(entries[0].title == "Nos vemos en la terraza.")
    #expect(!entries[0].text.contains("language:"))
    #expect(entries[0].markdown.contains("language: es"))
}

@Test func customHotkeyRequiresItsModifiers() {
    var tapper = HotkeyTapper(hotkey: Hotkey(keyCode: 49, modifiers: [.control, .option]))
    #expect(tapper.handle(.down(code: 49, isRepeat: false), modifiers: []) == false)
    #expect(tapper.handle(.up(code: 49), modifiers: []) == false)
    #expect(tapper.handle(.down(code: 49, isRepeat: false), modifiers: [.control, .option]) == false)
    #expect(tapper.handle(.down(code: 49, isRepeat: true), modifiers: [.control, .option]) == false)
    #expect(tapper.handle(.up(code: 49), modifiers: [.control, .option]) == true)
}

@Test func silentLongTakeDoesNotHallucinateOrSave() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let paster = SpyPaster()
    let session = makeSession(text: "hallucinated words", paster: paster, directory: dir)
    await session.toggle()
    await session.ingest(samples: Array(repeating: 0, count: 16_000), sampleRate: 16_000)
    await session.toggle()
    #expect(paster.pasted.isEmpty)
    #expect(await session.snapshot().phase == .failed)
    #expect(await session.snapshot().committedText.isEmpty)
    #expect(try HistoryLibrary.read(directory: dir).isEmpty)
}

struct BrokenTyper: CommandV {
    func commandV() async throws { throw AccessibilityDenied() }
}

@Test func clipboardIsRestoredWhenPasteThrows() async throws {
    let board = FakeBoard()
    board.string = "before the take"
    do {
        try await ClipboardPaster(board: board, typer: BrokenTyper()).paste("new words")
        Issue.record("Expected paste failure")
    } catch {}
    #expect(board.string == "before the take")
}

actor FinalPassRecognizer: SpeechRecognizer {
    var liveStarted = false
    private var live: CheckedContinuation<Transcript, Never>?
    private var calls = 0
    func transcribe(samples: [Float], sampleRate: Double) async throws -> Transcript {
        calls += 1
        if calls == 1 {
            liveStarted = true
            return await withCheckedContinuation { live = $0 }
        }
        return Transcript(words: [SpokenWord(text: "final words", start: 0, end: 1)], duration: 1)
    }
    func releaseLive() {
        live?.resume(returning: Transcript(words: [SpokenWord(text: "old live words", start: 0, end: 1)], duration: 1))
        live = nil
    }
}

@Test func finalPassWaitsForLiveInferenceAndCannotBeCancelledByClosingUI() async throws {
    let dir = try tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let recognizer = FinalPassRecognizer()
    let paster = SpyPaster()
    let session = DictationSession(pipeline: TranscriptionPipeline(recognizer: recognizer,
        ear: ScriptedEar(guess: LanguageGuess(language: "en", isReliable: true)), fillers: ScriptedUhm(spans: [])),
        paster: paster, history: HistoryWriter(directory: dir, redactor: FakeRedactor()),
        models: FlagCatalog(isReady: true), microphone: FlagMic(isAuthorized: true))
    await session.toggle()
    let live = Task { await session.ingest(samples: Array(repeating: 0.2, count: 20_000), sampleRate: 16_000) }
    while !(await recognizer.liveStarted) { await Task.yield() }
    let finish = Task { await session.toggle() }
    while await session.snapshot().phase != .finishing { await Task.yield() }
    await session.silence()
    #expect(await session.snapshot().phase == .finishing)
    await recognizer.releaseLive()
    await live.value
    await finish.value
    #expect(paster.pasted == ["final words"])
    #expect(await session.snapshot().committedText == "final words")
    #expect(try HistoryLibrary.read(directory: dir).count == 1)
}
