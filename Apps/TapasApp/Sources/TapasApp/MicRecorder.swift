import AVFoundation
import Foundation
import TapasCore

final class MicRecorder: Microphone, @unchecked Sendable {
    var onSamples: (@Sendable ([Float]) -> Void)?

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 16_000

    var isAuthorized: Bool {
        get async {
            AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }

    func start() async throws {
        let granted: Bool
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            granted = true
        } else {
            granted = await AVCaptureDevice.requestAccess(for: .audio)
        }
        guard granted else { throw CancellationError() }

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw CancellationError()
        }
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let converter, let converted = Self.convert(buffer, converter: converter, outputFormat: outputFormat) else { return }
            guard let channel = converted.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(converted.frameLength)))
            self?.onSamples?(samples)
        }
        try engine.start()
    }

    func stop() async -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return []
    }

    private static func convert(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let frames = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let out = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: max(frames, 1)) else { return nil }
        var error: NSError?
        var consumed = false
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .endOfStream
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil ? out : nil
    }
}
