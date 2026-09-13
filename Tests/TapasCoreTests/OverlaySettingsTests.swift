import Testing
@testable import TapasCore

@Test func micDeniedCopy() {
    #expect(
        OverlayCopy.message(for: .microphoneDenied)
            == "Microphone is off. Open System Settings to allow Tapas."
    )
}

@Test func emptyClipHasNoMessage() {
    #expect(OverlayCopy.message(for: .emptyClip) == nil)
}

@Test func defaultHistoryDirectoryEndsWithDictado() {
    let url = TapasSettings.defaultHistoryDirectory
    #expect(url.lastPathComponent == "dictado")
    #expect(url.deletingLastPathComponent().lastPathComponent == "tapas")
}
