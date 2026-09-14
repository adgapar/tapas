import AVFoundation
import Foundation
import TapasCore

final class MicRecorder: Microphone, @unchecked Sendable {
    var onSamples: (@Sendable ([Float]) -> Void)?

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 16_000
    private var buffersLogged = 0
    private let sampleLock = NSLock()
    private var recordedSamples: [Float] = []

    var isAuthorized: Bool {
        get async {
            AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }

    func requestAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        default:
            return await AVCaptureDevice.requestAccess(for: .audio)
        }
    }

    func start() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .denied, .restricted:
            tapasLog("mic denied")
            throw CancellationError()
        default:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else {
                tapasLog("mic denied")
                throw CancellationError()
            }
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.main.async {
                do {
                    try self.startEngine()
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func stop() async -> [Float] {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                self.stopEngine()
                cont.resume()
            }
        }
        return sampleLock.withLock {
            let result = recordedSamples
            recordedSamples = []
            return result
        }
    }

    private func startEngine() throws {
        let input = engine.inputNode
        if engine.isRunning {
            input.removeTap(onBus: 0)
            engine.stop()
        }
        try engine.start()
        var hardware = input.inputFormat(forBus: 0)
        if hardware.sampleRate < 1 {
            hardware = input.outputFormat(forBus: 0)
        }
        tapasLog("mic format sr=\(hardware.sampleRate) ch=\(hardware.channelCount)")
        guard hardware.sampleRate >= 1, hardware.channelCount >= 1 else {
            engine.stop()
            tapasLog("mic format invalid")
            throw CancellationError()
        }
        input.removeTap(onBus: 0)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            engine.stop()
            throw CancellationError()
        }
        guard let converter = AVAudioConverter(from: hardware, to: outputFormat) else {
            engine.stop()
            throw CancellationError()
        }
        sampleLock.withLock { recordedSamples = [] }
        buffersLogged = 0
        let sink = onSamples
        input.installTap(onBus: 0, bufferSize: 2048, format: hardware) { [weak self] buffer, _ in
            Self.deliver(buffer: buffer, converter: converter, outputFormat: outputFormat, recorder: self, sink: sink)
        }
        tapasLog("mic started")
    }

    private static func deliver(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat,
        recorder: MicRecorder?,
        sink: (@Sendable ([Float]) -> Void)?
    ) {
        guard let converted = convert(buffer, converter: converter, outputFormat: outputFormat) else { return }
        guard let channel = converted.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(converted.frameLength)))
        recorder?.sampleLock.withLock { recorder?.recordedSamples.append(contentsOf: samples) }
        if let recorder, recorder.buffersLogged < 8 {
            recorder.buffersLogged += 1
            tapasLog("mic #\(recorder.buffersLogged) n=\(samples.count) rms=\(PauseDetector.rms(samples))")
        }
        sink?(samples)
    }

    private func stopEngine() {
        tapasLog("mic stop")
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
    }

    private static func convert(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let inRate = max(buffer.format.sampleRate, 1)
        let ratio = outputFormat.sampleRate / inRate
        let frames = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let out = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: max(frames, 1)) else { return nil }
        var error: NSError?
        var consumed = false
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? out : nil
    }
}
