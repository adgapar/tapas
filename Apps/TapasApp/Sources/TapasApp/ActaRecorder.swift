@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import CoreMedia
import Foundation
import TapasCore

struct ActaAppSource: Identifiable, Hashable {
    let id: Int32
    let name: String
}

/// ScreenCaptureKit owns both inputs, so pause releases the microphone as well
/// as app audio. Only audio outputs are registered; no screen images are retained.
final class ActaRecorder: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "work.tapas.acta.audio")
    private var stream: SCStream?
    // Accessed only on queue, including the ordered ingestion chain.
    private var tail: Task<Void, Never>?
    private var session: ActaSession?
    private var accepting = false
    private var origin: Double = 0
    private var offset: Double = 0
    private var buffers: [ActaSource: [Float]] = [:]
    private var starts: [ActaSource: Double] = [:]
    private var ends: [ActaSource: Double] = [:]
    private var converters: [ActaSource: AVAudioConverter] = [:]
    private var lastLevels: [ActaSource: Double] = [:]
    private var lastSamples: [ActaSource: Double] = [:]
    var onFailure: (@Sendable (String) -> Void)?

    @MainActor static func sources() async throws -> [ActaAppSource] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let visiblePIDs = Set(content.windows.compactMap { $0.owningApplication?.processID })
        return content.applications.filter { $0.processID != ownPID && visiblePIDs.contains($0.processID) }
            .map { ActaAppSource(id: $0.processID, name: $0.applicationName) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @MainActor func start(app: ActaAppSource, session: ActaSession, offset: Double) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        guard let application = content.applications.first(where: { $0.processID == app.id }), let display = content.displays.first else {
            throw CaptureError.sourceUnavailable
        }
        let filter = SCContentFilter(display: display, including: [application], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.captureMicrophone = true
        config.sampleRate = 48_000
        config.channelCount = 1
        config.excludesCurrentProcessAudio = true
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(seconds: 1, preferredTimescale: 600)
        config.showsCursor = false
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
        queue.sync {
            self.session = session
            self.offset = offset
            self.origin = CMClockGetTime(CMClockGetHostTimeClock()).seconds
            self.buffers = [:]; self.starts = [:]; self.ends = [:]; self.converters = [:]
            self.lastLevels = [:]; self.lastSamples = [:]
            self.accepting = true
        }
        self.stream = stream
        do { try await stream.startCapture() }
        catch { _ = await stop(); throw error }
    }

    @MainActor func stop() async -> Double {
        if let stream { try? await stream.stopCapture() }
        stream = nil
        let result: (Double, Task<Void, Never>?) = queue.sync {
            accepting = false
            for source in [ActaSource.microphone, .app] {
                do {
                    let samples = try finishConversion(source: source)
                    if starts[source] == nil { starts[source] = ends[source] ?? offset }
                    buffers[source, default: []].append(contentsOf: samples)
                    while (buffers[source]?.count ?? 0) >= 80_000 { flush(source, count: 80_000) }
                } catch { onFailure?("The final audio buffer couldn’t be converted. The available recording is kept.") }
                flush(source)
            }
            let elapsed = max(0, CMClockGetTime(CMClockGetHostTimeClock()).seconds - origin)
            return (offset + elapsed, tail)
        }
        if let task = result.1 { await task.value }
        return result.0
    }

    func duration() -> Double {
        queue.sync { origin > 0 ? offset + max(0, CMClockGetTime(CMClockGetHostTimeClock()).seconds - origin) : offset }
    }

    func levels() -> (microphone: Double, app: Double, microphoneSeen: Bool, appSeen: Bool) {
        queue.sync {
            let now = CMClockGetTime(CMClockGetHostTimeClock()).seconds
            func recent(_ source: ActaSource) -> Bool { now - (lastSamples[source] ?? 0) < 3 }
            return (recent(.microphone) ? lastLevels[.microphone] ?? 0 : 0,
                    recent(.app) ? lastLevels[.app] ?? 0 : 0, recent(.microphone), recent(.app))
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onFailure?("Audio capture was interrupted. Acta paused; check the selected app and audio permissions, then resume.")
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard accepting, sampleBuffer.isValid, type == .audio || type == .microphone else { return }
        let source: ActaSource = type == .microphone ? .microphone : .app
        do {
            let samples = try convert(sampleBuffer, source: source)
            guard !samples.isEmpty else { return }
            let now = CMClockGetTime(CMClockGetHostTimeClock()).seconds
            lastLevels[source] = min(1, Double(PauseDetector.rms(samples)) * 8)
            lastSamples[source] = now
            let pts = sampleBuffer.presentationTimeStamp.seconds
            let timestamp = offset + max(0, (pts.isFinite ? pts : now) - origin)
            // Flush across gaps instead of pretending that missing audio was continuous.
            if let start = starts[source], let buffer = buffers[source],
               abs(timestamp - (start + Double(buffer.count) / 16_000)) > 0.25 { flush(source) }
            if starts[source] == nil { starts[source] = timestamp }
            buffers[source, default: []].append(contentsOf: samples)
            while (buffers[source]?.count ?? 0) >= 80_000 { flush(source, count: 80_000) }
        } catch {
            accepting = false
            onFailure?("An audio input changed or couldn’t be read. Acta paused; check your microphone and resume.")
        }
    }

    private func flush(_ source: ActaSource, count: Int? = nil) {
        guard let buffer = buffers[source], !buffer.isEmpty, let session else { return }
        let n = min(count ?? buffer.count, buffer.count)
        let samples = Array(buffer.prefix(n))
        let start = starts[source] ?? offset
        buffers[source] = Array(buffer.dropFirst(n))
        ends[source] = start + Double(n) / 16_000
        starts[source] = buffers[source]?.isEmpty == true ? nil : start + Double(n) / 16_000
        let previous = tail
        tail = Task {
            if let previous { await previous.value }
            await session.ingest(samples: samples, source: source, start: start)
        }
    }

    func convert(_ sample: CMSampleBuffer, source: ActaSource) throws -> [Float] {
        guard let description = sample.formatDescription, sample.numSamples > 0,
              CMAudioFormatDescriptionGetStreamBasicDescription(description) != nil else { throw CaptureError.invalidAudio }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        guard format.sampleRate > 0, format.channelCount > 0,
              let output = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sample.numSamples)) else { throw CaptureError.invalidAudio }
        input.frameLength = AVAudioFrameCount(sample.numSamples)
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(sample.numSamples), into: input.mutableAudioBufferList)
        guard status == noErr else { throw CaptureError.invalidAudio }
        var previousTail: [Float] = []
        if converters[source]?.inputFormat != format {
            previousTail = try finishConversion(source: source)
            let converter = AVAudioConverter(from: format, to: output)
            converters[source] = converter
        }
        guard let converter = converters[source],
              let converted = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: AVAudioFrameCount(ceil(Double(input.frameLength) * 16_000 / format.sampleRate)) + 32) else { throw CaptureError.invalidAudio }
        var consumed = false
        var error: NSError?
        converter.convert(to: converted, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return input
        }
        guard error == nil, let channel = converted.floatChannelData?[0] else { throw CaptureError.invalidAudio }
        return previousTail + Array(UnsafeBufferPointer(start: channel, count: Int(converted.frameLength)))
    }

    /// AVAudioConverter buffers a partial processing block between callbacks.
    /// End the stream explicitly on pause/device changes to retain that tail.
    func finishConversion(source: ActaSource) throws -> [Float] {
        guard let converter = converters.removeValue(forKey: source),
              let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: 4096) else { return [] }
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            status.pointee = .endOfStream
            return nil
        }
        guard error == nil, let channel = output.floatChannelData?[0] else { throw CaptureError.invalidAudio }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }

    enum CaptureError: LocalizedError {
        case sourceUnavailable, invalidAudio
        var errorDescription: String? {
            switch self {
            case .sourceUnavailable: "The selected app is no longer available. Open it and refresh the app list."
            case .invalidAudio: "The audio input couldn’t be converted. Check your audio device."
            }
        }
    }
}
