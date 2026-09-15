import Testing
@testable import TapasCore

@MainActor @Test func updateWaitsUntilRecordingAndRecoveryHaveFinished() {
    let gate = UpdateRelaunchGate()
    var installs = 0
    #expect(gate.postponeIfNeeded(busy: true) { installs += 1 })
    gate.resumeIfPossible(busy: true)
    #expect(installs == 0)
    #expect(gate.isWaiting)
    gate.resumeIfPossible(busy: false)
    gate.resumeIfPossible(busy: false)
    #expect(installs == 1)
    #expect(!gate.isWaiting)
}

@MainActor @Test func canceledUpdateCannotRelaunchWhenRecordingFinishes() {
    let gate = UpdateRelaunchGate()
    var installed = false
    _ = gate.postponeIfNeeded(busy: true) { installed = true }
    gate.cancel()
    gate.resumeIfPossible(busy: false)
    #expect(!installed)
    #expect(!gate.postponeIfNeeded(busy: false) { installed = true })
    #expect(!installed) // Sparkle owns an immediate, non-postponed installation.
}
