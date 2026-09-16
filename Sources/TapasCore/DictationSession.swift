import Foundation

public enum DictationPhase: String, Equatable, Sendable {
    case idle, starting, listening, finishing, delivered, recovery, failed
    public var isActive: Bool { self == .starting || self == .listening || self == .finishing }
}

public struct OverlaySnapshot: Equatable, Sendable {
    public var isVisible: Bool
    public var committedText: String
    public var rms: Float
    public var message: String?
    public var downloadFraction: Double?
    public var phase: DictationPhase
    public var pasteFailed: Bool
    public var saveFailed: Bool
    public var historyURL: URL?

    public init(isVisible: Bool = false, committedText: String = "", rms: Float = 0,
                message: String? = nil, downloadFraction: Double? = nil,
                phase: DictationPhase = .idle, pasteFailed: Bool = false,
                saveFailed: Bool = false, historyURL: URL? = nil) {
        self.isVisible = isVisible
        self.committedText = committedText
        self.rms = rms
        self.message = message
        self.downloadFraction = downloadFraction
        self.phase = phase
        self.pasteFailed = pasteFailed
        self.saveFailed = saveFailed
        self.historyURL = historyURL
    }
}

/// Owns a take independently of windows. UI dismissal never discards a result.
public actor DictationSession {
    public static let minimumDuration: TimeInterval = 0.25
    private let pipeline: TranscriptionPipeline
    private let paster: any TextPaster
    private var history: HistoryWriter
    private var takeHistory: HistoryWriter?
    private let models: any ModelCatalog
    private let microphone: any Microphone
    private let now: @Sendable () -> Date
    private let sampleRate: Double
    private var overlay = OverlaySnapshot()
    private var buffer: [Float] = []
    private var detector: PauseDetector
    private var lastLanguage: String?
    private var startedAt: Date?
    private var samplesSinceChunk = 0
    private var generation = 0
    private var chunkInFlight = false
    private var toggling = false
    private var cancelling = false
    private var historyEnabled = true
    private var saveThisTake = true
    private var pendingRecord: HistoryRecord?

    public init(pipeline: TranscriptionPipeline, paster: any TextPaster, history: HistoryWriter,
                models: any ModelCatalog, microphone: any Microphone, sampleRate: Double = 16_000,
                now: @escaping @Sendable () -> Date = Date.init) {
        self.pipeline = pipeline
        self.paster = paster
        self.history = history
        self.models = models
        self.microphone = microphone
        self.sampleRate = sampleRate
        self.now = now
        detector = PauseDetector(sampleRate: sampleRate)
    }

    public func snapshot() -> OverlaySnapshot { overlay }
    public func setHistoryEnabled(_ enabled: Bool) { historyEnabled = enabled }
    public func setHistoryDirectory(_ directory: URL) { history.directory = directory }

    public func toggle() async {
        guard !toggling, !cancelling else { return }
        // Recover or explicitly dismiss the retained result before replacing it.
        guard overlay.phase != .recovery else { return }
        toggling = true
        defer { toggling = false }
        if overlay.phase == .listening { await stop(); return }
        guard !overlay.phase.isActive else { return }
        generation += 1
        let take = generation
        takeHistory = history
        overlay = OverlaySnapshot(isVisible: true, phase: .starting)
        guard await models.isReady else {
            guard generation == take else { return }
            overlay = OverlaySnapshot(isVisible: true, message: OverlayCopy.message(for: .modelNotReady(fraction: nil)),
                                      downloadFraction: await models.downloadFraction, phase: .failed)
            return
        }
        guard await microphone.isAuthorized else {
            guard generation == take else { return }
            overlay = OverlaySnapshot(isVisible: true, message: OverlayCopy.message(for: .microphoneDenied), phase: .failed)
            return
        }
        guard generation == take else { return }
        buffer = []
        samplesSinceChunk = 0
        detector = PauseDetector(sampleRate: sampleRate)
        startedAt = now()
        saveThisTake = historyEnabled
        pendingRecord = nil
        do {
            try await microphone.start()
            guard generation == take else { _ = await microphone.stop(); return }
            overlay = OverlaySnapshot(isVisible: true, phase: .listening)
        } catch {
            _ = await microphone.stop()
            guard generation == take else { return }
            overlay = OverlaySnapshot(isVisible: true, message: "The microphone couldn’t start. Check your input device and try again.", phase: .failed)
        }
    }

    /// Cancel capture. Finalizing and retained results must finish or be dismissed explicitly.
    public func silence() async {
        guard overlay.phase == .listening || overlay.phase == .starting else { return }
        cancelling = true
        defer { cancelling = false }
        generation += 1
        overlay = OverlaySnapshot()
        buffer = []
        _ = await microphone.stop()
    }

    public func dismissResult() {
        guard !overlay.phase.isActive, !toggling else { return }
        overlay = OverlaySnapshot()
        pendingRecord = nil
    }

    public func ingest(samples: [Float], sampleRate: Double) async {
        guard overlay.phase == .listening, sampleRate == self.sampleRate else { return }
        buffer.append(contentsOf: samples)
        samplesSinceChunk += samples.count
        let event = detector.feed(samples)
        var shouldTranscribe = false
        switch event {
        case .speech(let rms):
            overlay.rms = rms
            shouldTranscribe = samplesSinceChunk >= Int(sampleRate * 1.2)
        case .pause:
            overlay.rms = 0
            shouldTranscribe = true
        }
        guard shouldTranscribe, !chunkInFlight else { return }
        samplesSinceChunk = 0
        chunkInFlight = true
        let take = generation
        defer { chunkInFlight = false }
        do {
            let result = try await pipeline.chunk(samples: buffer, sampleRate: sampleRate, lastLanguage: lastLanguage)
            guard generation == take, overlay.phase == .listening else { return }
            lastLanguage = result.language
            overlay.committedText = result.transcript.text
        } catch { /* Retain the previous live words until the final pass. */ }
    }

    private func stop() async {
        overlay.phase = .finishing
        overlay.message = "Finishing your thought…"
        overlay.rms = 0
        let samples = await microphone.stop()
        if !samples.isEmpty { buffer = samples }
        // One inference at a time; an older live pass must not overwrite the final result.
        while chunkInFlight { try? await Task.sleep(for: .milliseconds(20)) }
        let duration = Double(buffer.count) / sampleRate
        defer { buffer = []; detector = PauseDetector(sampleRate: sampleRate) }
        let hasSignal = stride(from: 0, to: buffer.count, by: 320).contains { offset in
            PauseDetector.rms(Array(buffer[offset..<min(offset + 320, buffer.count)])) >= PauseDetector.rmsThreshold
        }
        guard duration >= Self.minimumDuration, hasSignal else {
            overlay = OverlaySnapshot(isVisible: true, message: "No words came through. Nothing saved. Try another take.", phase: .failed)
            return
        }
        do {
            let result = try await pipeline.finish(samples: buffer, sampleRate: sampleRate, lastLanguage: lastLanguage)
            lastLanguage = result.language
            let text = result.transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                overlay = OverlaySnapshot(isVisible: true, message: "No words came through. Nothing saved. Try another take.", phase: .failed)
                return
            }
            overlay.committedText = text
            overlay.message = nil
            pendingRecord = HistoryRecord(startedAt: startedAt ?? now(), language: result.language,
                                          duration: duration, pastedText: text)
            // Delivery and history are independent: either failure must preserve the words.
            do { try await paster.paste(text) } catch { overlay.pasteFailed = true }
            if saveThisTake { await saveRecord() }
            completeDelivery()
        } catch {
            overlay.phase = overlay.committedText.isEmpty ? .failed : .recovery
            overlay.isVisible = true
            overlay.message = "The final transcription failed. Any live words below are kept; copy them before trying again."
        }
    }

    private func saveRecord() async {
        guard let pendingRecord, overlay.historyURL == nil else { return }
        do {
            overlay.historyURL = try await (takeHistory ?? history).write(pendingRecord)
            overlay.saveFailed = false
        } catch { overlay.saveFailed = true }
    }

    private func completeDelivery() {
        if overlay.pasteFailed || overlay.saveFailed {
            overlay.phase = .recovery
            overlay.isVisible = true
            let paste = overlay.pasteFailed ? "Paste wasn’t available. Copy your words or retry in the original app." : "Your words were sent to the app."
            let save = overlay.saveFailed ? " History couldn’t be saved. Retry saving or export a copy." : ""
            overlay.message = paste + save
        } else {
            overlay.phase = .delivered
            overlay.isVisible = false
            overlay.message = saveThisTake ? "Sent to your app. A copy is on your shelf." : "Sent to your app. History is off."
        }
    }

    public func retryPaste() async {
        guard overlay.pasteFailed, !toggling else { return }
        toggling = true
        defer { toggling = false }
        do { try await paster.paste(overlay.committedText); overlay.pasteFailed = false } catch {}
        completeDelivery()
    }

    public func retrySave() async {
        guard overlay.saveFailed, !toggling else { return }
        toggling = true
        defer { toggling = false }
        await saveRecord()
        completeDelivery()
    }
}
