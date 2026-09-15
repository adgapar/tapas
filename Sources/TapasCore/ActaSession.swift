import Foundation

public enum ActaPhase: String, Sendable { case idle, recording, paused, finishing, saved, recovery }
public enum ActaSource: String, Codable, Sendable { case microphone, app }

public struct ActaSegment: Codable, Equatable, Sendable {
    public var start: TimeInterval
    public var source: ActaSource
    public var text: String
    public var language: String?
    public init(start: TimeInterval, source: ActaSource, text: String, language: String?) {
        self.start = start; self.source = source; self.text = text; self.language = language
    }
}

public struct ActaDocument: Codable, Sendable {
    public var id = UUID()
    public var startedAt = Date()
    public var appName: String
    public var duration: TimeInterval = 0
    public var segments: [ActaSegment] = []
    public var processedChunks: Set<UUID> = []
    public var interruptions: [String] = []

    public init(appName: String) { self.appName = appName }

    public var markdown: String {
        let languages = Set(segments.compactMap(\.language)).sorted().joined(separator: ", ")
        let source = appName.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        var result = """
        ---
        tool: acta
        time: \(ISO8601DateFormatter().string(from: startedAt))
        duration: \(duration)
        languages: [\(languages)]
        ---

        # Acta · \(source)

        Recorded time excludes pauses. Labels identify audio sources, not speakers.

        """
        for segment in segments.sorted(by: { $0.start < $1.start }) {
            result += "\n[\(Self.timestamp(segment.start))] **\(segment.source == .microphone ? "Microphone" : "App audio")**: \(segment.text)\n"
        }
        if segments.isEmpty { result += "\nNo speech was recognized.\n" }
        if !interruptions.isEmpty {
            result += "\n## Recording notes\n\n" + interruptions.map { "- \($0)" }.joined(separator: "\n") + "\n"
        }
        return result
    }

    public static func timestamp(_ seconds: TimeInterval) -> String {
        let value = seconds.isFinite ? max(0, Int(seconds)) : 0
        return String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
    }
}

public struct ActaSnapshot: Sendable {
    public var phase: ActaPhase = .idle
    public var document: ActaDocument?
    public var message: String?
    public var savedURL: URL?
    public var pendingChunks = 0
    public init() {}
}

/// Bounded audio chunks are journaled before recognition. A restart can replay any
/// unfinished chunks without duplicating text that was already checkpointed.
public actor ActaSession {
    private struct AudioChunk: Codable {
        var id = UUID()
        var source: ActaSource
        var start: TimeInterval
        var samples: [Float]
    }
    private let pipeline: TranscriptionPipeline
    private let recoveryRoot: URL
    private let outputDirectory: URL
    private var state = ActaSnapshot()
    private var pending: [URL] = []
    private var worker: Task<Void, Never>?
    // Keep a failed disk write in memory as well; never pretend those words were saved.
    private var unwritten: [AudioChunk] = []
    private var processingFailed = false

    public init(pipeline: TranscriptionPipeline, recoveryRoot: URL, outputDirectory: URL) {
        self.pipeline = pipeline
        self.recoveryRoot = recoveryRoot
        self.outputDirectory = outputDirectory
    }

    public func snapshot() -> ActaSnapshot {
        var result = state
        result.pendingChunks = pending.count + unwritten.count
        return result
    }

    private var directory: URL { recoveryRoot.appendingPathComponent(state.document!.id.uuidString, isDirectory: true) }

    public func recover() throws {
        guard state.phase == .idle else { return }
        guard FileManager.default.fileExists(atPath: recoveryRoot.path) else { return }
        let folders = try FileManager.default.contentsOfDirectory(at: recoveryRoot, includingPropertiesForKeys: nil).sorted { $0.lastPathComponent < $1.lastPathComponent }
        for folder in folders {
            let journal = folder.appendingPathComponent("session.json")
            guard FileManager.default.fileExists(atPath: journal.path) else { continue }
            let document = try JSONDecoder().decode(ActaDocument.self, from: Data(contentsOf: journal))
            guard folder.lastPathComponent == document.id.uuidString else { throw CocoaError(.fileReadCorruptFile) }
            let chunks = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("audio-") }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            state.document = document
            state.phase = .paused
            state.message = "An interrupted meeting was recovered. Finish to transcribe and save it."
            pending = chunks
            return
        }
    }

    public func newMeeting() throws {
        guard state.phase == .saved else { return }
        state = ActaSnapshot()
        pending = []
        processingFailed = false
        try recover()
    }

    public func start(appName: String) throws {
        guard state.phase == .idle || state.phase == .saved else { return }
        state = ActaSnapshot()
        state.document = ActaDocument(appName: appName)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try checkpoint()
            state.phase = .recording
            processingFailed = false
        } catch {
            state.phase = .recovery
            state.message = "Acta couldn’t create its recovery files. Check available disk space and folder access."
            throw error
        }
    }

    public func resume() throws {
        guard state.phase == .paused, !processingFailed else { return }
        state.phase = .recording
        state.message = nil
        try checkpoint()
        launchWorker()
    }

    public func ingest(samples: [Float], source: ActaSource, start: TimeInterval) {
        guard state.phase == .recording, !samples.isEmpty, start.isFinite else { return }
        // The capture adapter sends at most five seconds at 16 kHz, mono.
        guard samples.count <= 80_000, samples.allSatisfy(\.isFinite) else {
            processingFailed = true
            state.message = "Audio arrived in an unsupported format. Pause and finish this meeting."
            return
        }
        let chunk = AudioChunk(source: source, start: max(0, start), samples: samples)
        extendDuration(to: chunk.start + Double(samples.count) / 16_000)
        do {
            try persist(chunk)
            try checkpoint()
            launchWorker()
        } catch {
            // persist may have succeeded before the metadata write failed.
            if !pending.contains(where: { $0.lastPathComponent.contains(chunk.id.uuidString) }) { unwritten.append(chunk) }
            processingFailed = true
            state.message = "Recovery storage is unavailable. Pause now; retry saving after freeing disk space."
        }
    }

    public func pause(duration: TimeInterval, note: String? = nil) {
        guard state.phase == .recording else { return }
        state.phase = .paused
        extendDuration(to: duration)
        if let note {
            state.document?.interruptions.append("[\(ActaDocument.timestamp(duration))] \(note)")
            state.message = note
        }
        do { try checkpoint() }
        catch { processingFailed = true; state.message = "The recovery file couldn’t be updated. Retry saving before quitting." }
    }

    public func discard() async throws {
        guard [.paused, .recovery].contains(state.phase), state.document != nil else { return }
        state.phase = .finishing
        if let worker { await worker.value }
        do {
            if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
            pending = []; unwritten = []; processingFailed = false
            state = ActaSnapshot()
        } catch {
            state.phase = .recovery
            state.message = "The recovery files couldn’t be removed. Check folder access and try again."
            throw error
        }
        try recover()
    }

    public func finish() async {
        guard [.paused, .recording, .recovery].contains(state.phase), state.document != nil else { return }
        state.phase = .finishing
        state.message = nil
        if let worker { await worker.value }
        processingFailed = false
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            while let chunk = unwritten.first {
                try persist(chunk)
                unwritten.removeFirst()
            }
            try checkpoint()
            launchWorker()
            if let worker { await worker.value }
            guard !processingFailed, pending.isEmpty else { state.phase = .recovery; return }
            guard let document = state.document else { return }
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let url = outputDirectory.appendingPathComponent("\(HistoryWriter.filename(for: document.startedAt).dropLast(3))-\(document.id.uuidString).md")
            try Data(document.markdown.utf8).write(to: url, options: .atomic)
            // Cleanup is part of completing the save: a retry uses the same output path.
            try FileManager.default.removeItem(at: directory)
            state.savedURL = url
            state.message = nil
            state.phase = .saved
        } catch {
            state.phase = .recovery
            state.message = "The meeting couldn’t be saved. Your transcript and pending audio are retained. Retry or export the available text."
        }
    }

    private func extendDuration(to duration: TimeInterval) {
        let value = max(state.document?.duration ?? 0, duration.isFinite ? duration : 0)
        state.document?.duration = value
    }

    private func persist(_ chunk: AudioChunk) throws {
        let url = directory.appendingPathComponent("audio-\(String(format: "%012.3f", chunk.start))-\(chunk.id.uuidString).json")
        try JSONEncoder().encode(chunk).write(to: url, options: .atomic)
        if !pending.contains(url) { pending.append(url) }
    }

    private func checkpoint() throws {
        guard let document = state.document else { return }
        try JSONEncoder().encode(document).write(to: directory.appendingPathComponent("session.json"), options: .atomic)
    }

    private func launchWorker() {
        guard worker == nil, !processingFailed, !pending.isEmpty else { return }
        worker = Task { await self.processPending() }
    }

    private func processPending() async {
        defer { worker = nil }
        while let url = pending.first {
            do {
                let chunk = try JSONDecoder().decode(AudioChunk.self, from: Data(contentsOf: url))
                if state.document?.processedChunks.contains(chunk.id) != true {
                    // Quiet chunks remain represented in duration, without hallucinated speech.
                    if PauseDetector.rms(chunk.samples) > 0.002 {
                        let result = try await pipeline.chunk(samples: chunk.samples, sampleRate: 16_000, lastLanguage: nil)
                        let text = result.transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty {
                            state.document?.segments.append(ActaSegment(start: chunk.start, source: chunk.source, text: text, language: result.language))
                        }
                    }
                    extendDuration(to: chunk.start + Double(chunk.samples.count) / 16_000)
                    state.document?.processedChunks.insert(chunk.id)
                }
                // Always checkpoint before removing a chunk, including after a failed checkpoint.
                try checkpoint()
                try FileManager.default.removeItem(at: url)
                pending.removeFirst()
            } catch {
                processingFailed = true
                state.message = "Some meeting audio is waiting to be transcribed. Pause and finish to retry; recovery audio is kept on this Mac."
                return
            }
        }
    }
}
