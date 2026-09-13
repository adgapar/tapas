import Foundation

public struct PauseDetector: Sendable {
    public enum Event: Equatable, Sendable {
        case speech(rms: Float)
        case pause
    }

    public static let pauseDuration: TimeInterval = 0.40
    public static let rmsThreshold: Float = 0.01
    public static let frameDuration: TimeInterval = 0.020

    private let sampleRate: Double
    private var quietSamples = 0
    private var armed = false

    public init(sampleRate: Double = 16_000) {
        self.sampleRate = sampleRate
    }

    public mutating func feed(_ samples: [Float]) -> Event {
        let rms = Self.rms(samples)
        let needed = Int(sampleRate * Self.pauseDuration)
        if rms < Self.rmsThreshold {
            quietSamples += samples.count
            if armed && quietSamples >= needed {
                armed = false
                quietSamples = 0
                return .pause
            }
            return .speech(rms: rms)
        }
        quietSamples = 0
        armed = true
        return .speech(rms: rms)
    }

    public static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for s in samples { sum += s * s }
        return (sum / Float(samples.count)).squareRoot()
    }
}
