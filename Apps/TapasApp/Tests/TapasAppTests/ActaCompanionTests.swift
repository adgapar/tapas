import Testing
import TapasCore
@testable import TapasApp

@Test func actaWaveformKeepsMeasuredHistoryAndSettlesToSilence() {
    var history = ActaWaveformHistory()
    history.append(0.2)
    history.append(0.8)
    history.append(0.1)
    #expect(Array(history.levels.suffix(3)) == [0.2, 0.8, 0.1])
    for _ in 0..<24 { history.append(0) }
    #expect(history.levels.count == 24)
    #expect(history.levels.allSatisfy { $0 == 0 })
    for value in [Double.nan, .infinity, -1, 2] { history.append(value) }
    #expect(Array(history.levels.suffix(4)) == [0, 0, 0, 1])
}

@MainActor @Test func actaCompanionStaysCompactUntilAttentionIsNeeded() {
    let model = ActaModel()
    for phase in [ActaPhase.recording, .paused, .finishing] {
        model.snapshot.phase = phase
        #expect(!model.companionNeedsDetails)
        #expect(model.companionSize.height == 176)
    }
    model.error = "Capture interrupted"
    #expect(model.companionNeedsDetails)
    model.error = nil
    model.snapshot.phase = .recovery
    #expect(model.companionNeedsDetails)
    model.snapshot.phase = .saved
    #expect(model.companionNeedsDetails)
    #expect(!model.hasSession)
}

@Test func actaPintxoHoldsAcrossWordGapsAndReturnsInSilence() {
    var history = ActaWaveformHistory()
    #expect(!history.hasRecentAudio)
    history.append(0.4)
    for _ in 0..<6 { history.append(0) }
    #expect(history.hasRecentAudio)
    history.append(0)
    #expect(!history.hasRecentAudio)
    history.append(0.01)
    #expect(!history.hasRecentAudio)
}
