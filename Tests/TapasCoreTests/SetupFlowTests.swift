import Testing
@testable import TapasCore

@Test func firstLaunchStartsAtPeek() {
    let flow = SetupFlow.start(microphoneGranted: false, accessibilityTrusted: false, modelsReady: false)
    #expect(flow.phase == .peek)
    #expect(flow.canContinue)
}

@Test func peekIntroStatesWhatTapasIs() {
    let flow = SetupFlow(phase: .peek)
    #expect(flow.speech == "tapas")
    #expect(flow.primaryTitle == "Show me")
    #expect(flow.body.contains("plate"))
    #expect(flow.body.contains("Dictado"))
    #expect(flow.body.contains("Mac"))
    #expect(flow.body.contains("Documents"))
    #expect(!flow.body.contains("I'll type what you say."))
}

@Test func continueFromPeekGoesToMicrophone() {
    var flow = SetupFlow.start(microphoneGranted: false, accessibilityTrusted: false, modelsReady: false)
    flow.advance()
    #expect(flow.phase == .microphone)
    #expect(!flow.canContinue)
}

@Test func microphoneBlocksUntilGranted() {
    var flow = SetupFlow(phase: .microphone, microphoneGranted: false, accessibilityTrusted: false, tapStarted: false, modelsReady: false)
    flow.advance()
    #expect(flow.phase == .microphone)
    flow.microphoneGranted = true
    flow.advance()
    #expect(flow.phase == .accessibility)
}

@Test func accessibilityCanMoveOnWithoutTheTap() {
    var flow = SetupFlow(phase: .accessibility, microphoneGranted: true, accessibilityTrusted: true, tapStarted: false, modelsReady: false)
    #expect(flow.canContinue)
    #expect(flow.primaryTitle == "Next")
    #expect(flow.secondaryTitle == "Open Settings")
    flow.advance()
    #expect(flow.phase == .kitchen)
}

@Test func accessibilityCanBeDeferredBeforeGranting() {
    var flow = SetupFlow(phase: .accessibility, microphoneGranted: true, accessibilityTrusted: false, tapStarted: false, modelsReady: false)
    #expect(flow.canContinue)
    #expect(flow.primaryTitle == "Later")
    flow.advance()
    #expect(flow.phase == .kitchen)
}

@Test func kitchenBlocksUntilReadyThenTryIt() {
    var flow = SetupFlow(phase: .kitchen, microphoneGranted: true, accessibilityTrusted: true, tapStarted: true, modelsReady: false)
    #expect(!flow.canContinue)
    #expect(flow.primaryTitle.isEmpty)
    flow.modelsReady = true
    flow.advance()
    #expect(flow.phase == .tryIt)
}

@Test func readyKitchenSkipsStraightToTryIt() {
    var flow = SetupFlow(phase: .accessibility, microphoneGranted: true, accessibilityTrusted: true, tapStarted: true, modelsReady: true)
    flow.advance()
    #expect(flow.phase == .tryIt)
}

@Test func tryItCopyUsesTheHotkeyLabel() {
    var flow = SetupFlow(phase: .tryIt, microphoneGranted: true, modelsReady: true)
    #expect(flow.speech == "⌃⌥. Talk.")
    flow.hotkeyLabel = "Right ⌘"
    #expect(flow.speech == "Right ⌘. Talk.")
}

@Test func tryItFinishes() {
    var flow = SetupFlow(phase: .tryIt, microphoneGranted: true, accessibilityTrusted: true, tapStarted: true, modelsReady: true)
    #expect(flow.canContinue)
    flow.advance()
    #expect(flow.phase == .finished)
}

@Test func returningUserSkipsToKitchen() {
    let flow = SetupFlow.start(microphoneGranted: true, accessibilityTrusted: true, modelsReady: false)
    #expect(flow.phase == .kitchen)
}

@Test func everythingReadyLandsOnTryIt() {
    let flow = SetupFlow.start(microphoneGranted: true, accessibilityTrusted: true, modelsReady: true)
    #expect(flow.phase == .tryIt)
}

@Test func setupCopyHidesVendorAndLanguages() {
    let phases: [SetupPhase] = [.peek, .microphone, .accessibility, .kitchen, .tryIt, .finished]
    let leaks = ["Voz", "Ear", "Uhm", "English", "Spanish", "Russian", "Parakeet", "Desert", "Neural"]
    for phase in phases {
        let flow = SetupFlow(phase: phase, modelsReady: false, modelError: "The kitchen didn't make it.")
        let blob = flow.title + flow.body + flow.speech + flow.primaryTitle + (flow.detail ?? "")
        for leak in leaks {
            #expect(!blob.contains(leak), "\(phase) leaked \(leak)")
        }
    }
    #expect(OverlayCopy.message(for: .modelNotReady(fraction: 0.2)) == "Prepare the voice models in Setup to start Dictado.")
}
