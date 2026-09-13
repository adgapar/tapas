import Foundation

public struct OverlaySnapshot: Equatable, Sendable {
    public var isVisible: Bool
    public var committedText: String
    public var rms: Float
    public var message: String?
    public var downloadFraction: Double?

    public init(
        isVisible: Bool = false,
        committedText: String = "",
        rms: Float = 0,
        message: String? = nil,
        downloadFraction: Double? = nil
    ) {
        self.isVisible = isVisible
        self.committedText = committedText
        self.rms = rms
        self.message = message
        self.downloadFraction = downloadFraction
    }
}

public actor DictationSession {
    public static let minimumDuration: TimeInterval = 0.25

    private let pipeline: TranscriptionPipeline
    private let paster: any TextPaster
    private let history: HistoryWriter
    private let models: any ModelCatalog
    private let microphone: any Microphone
    private let now: @Sendable () -> Date
    private let sampleRate: Double

    private var listening = false
    private var overlay = OverlaySnapshot()
    private var buffer: [Float] = []
    private var detector: PauseDetector
    private var lastLanguage: String?
    private var startedAt: Date?

    public init(
        pipeline: TranscriptionPipeline,
        paster: any TextPaster,
        history: HistoryWriter,
        models: any ModelCatalog,
        microphone: any Microphone,
        sampleRate: Double = 16_000,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.pipeline = pipeline
        self.paster = paster
        self.history = history
        self.models = models
        self.microphone = microphone
        self.sampleRate = sampleRate
        self.now = now
        self.detector = PauseDetector(sampleRate: sampleRate)
    }

    public func snapshot() -> OverlaySnapshot { overlay }

    public func toggle() async {
        if listening {
            await stop()
            return
        }
        if !(await models.isReady) {
            overlay = OverlaySnapshot(
                isVisible: true,
                message: OverlayCopy.message(for: .modelNotReady(fraction: await models.downloadFraction)),
                downloadFraction: await models.downloadFraction
            )
            return
        }
        if !(await microphone.isAuthorized) {
            overlay = OverlaySnapshot(
                isVisible: true,
                message: OverlayCopy.message(for: .microphoneDenied)
            )
            return
        }
        listening = true
        buffer = []
        detector = PauseDetector(sampleRate: sampleRate)
        startedAt = now()
        overlay = OverlaySnapshot(isVisible: true)
        do {
            try await microphone.start()
        } catch {
            listening = false
            overlay = OverlaySnapshot(
                isVisible: true,
                message: OverlayCopy.message(for: .microphoneDenied)
            )
        }
    }

    public func ingest(samples: [Float], sampleRate: Double) async {
        guard listening else { return }
        buffer.append(contentsOf: samples)
        let event = detector.feed(samples)
        switch event {
        case .speech(let rms):
            overlay.rms = rms
        case .pause:
            overlay.rms = 0
            await transcribeChunk()
        }
    }

    private func transcribeChunk() async {
        let committed = overlay.committedText
        do {
            let result = try await pipeline.chunk(
                samples: buffer,
                sampleRate: sampleRate,
                lastLanguage: lastLanguage
            )
            lastLanguage = result.language
            overlay.committedText = result.transcript.text
        } catch {
            overlay.committedText = committed
        }
    }

    private func stop() async {
        listening = false
        let samples = await microphone.stop()
        if !samples.isEmpty { buffer = samples }
        let duration = Double(buffer.count) / sampleRate
        defer {
            buffer = []
            detector = PauseDetector(sampleRate: sampleRate)
        }
        guard duration >= Self.minimumDuration else {
            overlay = OverlaySnapshot()
            return
        }
        do {
            let result = try await pipeline.finish(
                samples: buffer,
                sampleRate: sampleRate,
                lastLanguage: lastLanguage
            )
            lastLanguage = result.language
            let text = result.transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                overlay = OverlaySnapshot()
                return
            }
            let tapa = Orden.classify(text)
            overlay.committedText = text
            overlay.isVisible = true
            overlay.message = nil
            if tapa == .dictado {
                try await paster.paste(text)
                _ = try await history.write(
                    HistoryRecord(
                        startedAt: startedAt ?? now(),
                        language: result.language,
                        duration: duration,
                        pastedText: text
                    )
                )
            }
            overlay = OverlaySnapshot()
        } catch is AccessibilityDenied {
            overlay = OverlaySnapshot(
                isVisible: true,
                message: OverlayCopy.message(for: .accessibilityDenied)
            )
        } catch {
            overlay = OverlaySnapshot()
        }
    }
}
