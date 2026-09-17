import Testing
@testable import TapasCore

@Test func micDeniedCopy() {
    #expect(
        OverlayCopy.message(for: .microphoneDenied)
            == "Microphone is off. Open System Settings to allow tapas."
    )
}

@Test func emptyClipAsksToTalkAgain() {
    #expect(OverlayCopy.message(for: .emptyClip) == "Too short. Talk, then press again.")
}

@Test func setupGateKeepsWaitingWhenAccessibilityIsOff() {
    #expect(SetupGate.message(trusted: false, tapStarted: false) == OverlayCopy.message(for: .accessibilityDenied))
}

@Test func setupGateAsksForRelaunchWhenTrustedButTapFailed() {
    let text = SetupGate.message(trusted: true, tapStarted: false)
    #expect(text?.contains("Quit tapas") == true)
}

@Test func setupGateIsSilentWhenTapWorks() {
    #expect(SetupGate.message(trusted: true, tapStarted: true) == nil)
}

@Test func defaultHistoryDirectoryEndsWithDictado() {
    let url = TapasSettings.defaultHistoryDirectory
    #expect(url.lastPathComponent == "dictado")
    #expect(url.deletingLastPathComponent().lastPathComponent == "tapas")
}
