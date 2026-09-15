import AVFoundation
import CoreMedia
import Testing
@testable import TapasApp

private func audioSample(rate: Double, channels: AVAudioChannelCount, integer: Bool = false) throws -> CMSampleBuffer {
    let format = try #require(AVAudioFormat(commonFormat: integer ? .pcmFormatInt16 : .pcmFormatFloat32, sampleRate: rate, channels: channels, interleaved: false))
    let pcm = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rate / 10)))
    pcm.frameLength = pcm.frameCapacity
    for channel in 0..<Int(channels) {
        for frame in 0..<Int(pcm.frameLength) {
            if integer { pcm.int16ChannelData![channel][frame] = 8192 }
            else { pcm.floatChannelData![channel][frame] = 0.25 }
        }
    }
    var sample: CMSampleBuffer?
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: Int32(rate)), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
    let status = CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil, refcon: nil, formatDescription: format.formatDescription, sampleCount: Int(pcm.frameLength), sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample)
    #expect(status == noErr)
    let result = try #require(sample)
    #expect(CMSampleBufferSetDataBufferFromAudioBufferList(result, blockBufferAllocator: kCFAllocatorDefault, blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0, bufferList: pcm.audioBufferList) == noErr)
    #expect(CMSampleBufferSetDataReady(result) == noErr)
    return result
}

@Test func actaConvertsAppAudioToMono16k() throws {
    let recorder = ActaRecorder()
    var samples: [Float] = []
    for _ in 0..<10 { samples += try recorder.convert(audioSample(rate: 48_000, channels: 2), source: .app) }
    samples += try recorder.finishConversion(source: .app)
    #expect(abs(samples.count - 16_000) <= 1)
    #expect(samples.allSatisfy { $0.isFinite })
    #expect(abs(samples.suffix(500).reduce(0, +) / 500 - 0.25) < 0.01)
}

@Test func actaConvertsNativeMicrophoneAndHandlesFormatChanges() throws {
    let recorder = ActaRecorder()
    let integer = try recorder.convert(audioSample(rate: 44_100, channels: 1, integer: true), source: .microphone)
    let floating = try recorder.convert(audioSample(rate: 48_000, channels: 1), source: .microphone)
    let tail = try recorder.finishConversion(source: .microphone)
    let samples = integer + floating + tail
    #expect(abs(samples.count - 3200) <= 2)
    #expect(abs(samples.suffix(500).reduce(0, +) / 500 - 0.25) < 0.01)
    #expect(try recorder.finishConversion(source: .microphone).isEmpty)
}
