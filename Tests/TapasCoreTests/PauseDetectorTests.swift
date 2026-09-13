import Testing
@testable import TapasCore

@Test func leadingSilenceIsNotAPause() {
    var detector = PauseDetector(sampleRate: 16_000)
    let frame = [Float](repeating: 0, count: 320)
    var sawPause = false
    for _ in 0..<20 {
        if case .pause = detector.feed(frame) { sawPause = true }
    }
    #expect(!sawPause)
}

@Test func loudSpeechIsNotAPause() {
    var detector = PauseDetector(sampleRate: 16_000)
    let frame = [Float](repeating: 0.2, count: 320)
    for _ in 0..<30 {
        if case .pause = detector.feed(frame) {
            Issue.record("loud frame counted as pause")
        }
    }
}

@Test func speechThenSilenceEmitsPauseOnce() {
    var detector = PauseDetector(sampleRate: 16_000)
    let loud = [Float](repeating: 0.2, count: 320)
    let quiet = [Float](repeating: 0, count: 320)
    for _ in 0..<10 { _ = detector.feed(loud) }
    var pauses = 0
    for _ in 0..<25 {
        if case .pause = detector.feed(quiet) { pauses += 1 }
    }
    #expect(pauses == 1)
}
