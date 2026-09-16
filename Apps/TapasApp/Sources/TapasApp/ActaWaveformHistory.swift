import Foundation

/// A bounded history of measured levels, sampled by the UI's 100 ms refresh.
struct ActaWaveformHistory {
    private(set) var levels = [Double](repeating: 0, count: 24)

    // Hold across short gaps between words; settle back after ~700 ms of quiet.
    var hasRecentAudio: Bool { levels.suffix(7).contains { $0 > 0.025 } }

    mutating func append(_ level: Double) {
        levels.removeFirst()
        levels.append(level.isFinite ? min(1, max(0, level)) : 0)
    }
}
