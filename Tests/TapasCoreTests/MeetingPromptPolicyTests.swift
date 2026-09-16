import Testing
@testable import TapasCore

@Test func meetingPromptWaitsForSustainedMicUseAndOffersOnlyOnce() {
    var policy = MeetingPromptPolicy()
    #expect(policy.update(activeApps: ["zoom"], now: 0, canPrompt: true, actaInProgress: false) == nil)
    #expect(policy.update(activeApps: ["zoom"], now: 2, canPrompt: true, actaInProgress: false) == nil)
    #expect(policy.update(activeApps: ["zoom"], now: 3, canPrompt: true, actaInProgress: false) == "zoom")
    #expect(policy.update(activeApps: ["zoom"], now: 4, canPrompt: true, actaInProgress: false) == nil)
    // Simulate continuous snapshots after dismissing the offer.
    for time in stride(from: 5.0, through: 180.0, by: 1) {
        #expect(policy.update(activeApps: ["zoom"], now: time, canPrompt: true, actaInProgress: false) == nil)
    }
}

@Test func meetingPromptIgnoresShortChecksAndMuteReconnects() {
    var policy = MeetingPromptPolicy()
    #expect(policy.update(activeApps: ["browser"], now: 0, canPrompt: true, actaInProgress: false) == nil)
    #expect(policy.update(activeApps: [], now: 2, canPrompt: true, actaInProgress: false) == nil)
    #expect(policy.update(activeApps: ["browser"], now: 3, canPrompt: true, actaInProgress: false) == nil)
    #expect(policy.update(activeApps: ["browser"], now: 6, canPrompt: true, actaInProgress: false) == "browser")
    #expect(policy.update(activeApps: [], now: 7, canPrompt: true, actaInProgress: false) == nil)
    #expect(policy.update(activeApps: ["browser"], now: 20, canPrompt: true, actaInProgress: false) == nil)
    for time in stride(from: 21.0, through: 90.0, by: 1) {
        #expect(policy.update(activeApps: ["browser"], now: time, canPrompt: true, actaInProgress: false) == nil)
    }
}

@Test func meetingPromptRearmsAfterAnInactiveMinute() {
    var policy = MeetingPromptPolicy()
    _ = policy.update(activeApps: ["teams"], now: 0, canPrompt: true, actaInProgress: false)
    #expect(policy.update(activeApps: ["teams"], now: 3, canPrompt: true, actaInProgress: false) == "teams")
    _ = policy.update(activeApps: [], now: 4, canPrompt: true, actaInProgress: false)
    #expect(policy.update(activeApps: ["teams"], now: 64, canPrompt: true, actaInProgress: false) == nil)
    #expect(policy.update(activeApps: ["teams"], now: 67, canPrompt: true, actaInProgress: false) == "teams")
}

@Test func meetingPromptDefersDuringDictadoButConsumesActivityDuringActa() {
    var policy = MeetingPromptPolicy()
    _ = policy.update(activeApps: ["zoom"], now: 0, canPrompt: false, actaInProgress: false)
    #expect(policy.update(activeApps: ["zoom"], now: 3, canPrompt: false, actaInProgress: false) == nil)
    #expect(policy.update(activeApps: ["zoom"], now: 4, canPrompt: true, actaInProgress: false) == "zoom")
    var recording = MeetingPromptPolicy()
    _ = recording.update(activeApps: ["zoom"], now: 0, canPrompt: false, actaInProgress: true)
    #expect(recording.update(activeApps: ["zoom"], now: 10, canPrompt: true, actaInProgress: false) == nil)
}

@Test func meetingPromptOffersForegroundFirstAndSuppressesCooccurringApps() {
    var policy = MeetingPromptPolicy()
    _ = policy.update(activeApps: ["browser", "zoom"], now: 0, canPrompt: true, actaInProgress: false)
    #expect(policy.update(activeApps: ["zoom", "browser"], now: 3, canPrompt: true, actaInProgress: false) == "zoom")
    for time in stride(from: 4.0, through: 90.0, by: 1) {
        #expect(policy.update(activeApps: ["browser"], now: time, canPrompt: true, actaInProgress: false) == nil)
    }
}

@Test func microphoneAttributionExcludesTapasAndUnknownProcesses() {
    let apps = [MicrophoneApp(pid: 1, bundleID: "work.tapas.Tapas", name: "Tapas"),
                MicrophoneApp(pid: 2, bundleID: "com.google.Chrome", name: "Chrome")]
    #expect(MicrophoneAppAttribution.owner(pid: 1, bundleID: "work.tapas.Tapas", apps: apps, ownPID: 1, ownBundleID: "work.tapas.Tapas") == nil)
    #expect(MicrophoneAppAttribution.owner(pid: 3, bundleID: "work.tapas.Tapas.helper", apps: apps, ownPID: 1, ownBundleID: "work.tapas.Tapas") == nil)
    #expect(MicrophoneAppAttribution.owner(pid: 3, bundleID: "com.apple.UnknownService", apps: apps, ownPID: 1, ownBundleID: "work.tapas.Tapas") == nil)
    #expect(MicrophoneAppAttribution.owner(pid: 3, bundleID: "com.google.ChromeCanary", apps: apps, ownPID: 1, ownBundleID: "work.tapas.Tapas") == nil)
}

@Test func microphoneAttributionResolvesBrowserHelperWithoutForegroundGuessing() {
    let chrome = MicrophoneApp(pid: 2, bundleID: "com.google.Chrome", name: "Chrome")
    let apps = [chrome, MicrophoneApp(pid: 4, bundleID: "us.zoom.xos", name: "Zoom")]
    #expect(MicrophoneAppAttribution.owner(pid: 8, bundleID: "com.google.Chrome.helper", apps: apps, ownPID: 1, ownBundleID: "work.tapas.Tapas") == chrome)
    #expect(MicrophoneAppAttribution.owner(pid: 2, bundleID: nil, apps: apps, ownPID: 1, ownBundleID: "work.tapas.Tapas") == chrome)
}

@Test func microphoneAttributionResolvesArcHelperWithDifferentBundleIDCasing() {
    let arc = MicrophoneApp(pid: 2, bundleID: "company.thebrowser.Browser", name: "Arc")
    let apps = [arc]
    #expect(MicrophoneAppAttribution.owner(pid: 8, bundleID: "company.thebrowser.browser.helper", apps: apps, ownPID: 1, ownBundleID: "work.tapas.Tapas") == arc)
    #expect(MicrophoneAppAttribution.owner(pid: 8, bundleID: "COMPANY.THEBROWSER.BROWSER", apps: apps, ownPID: 1, ownBundleID: "work.tapas.Tapas") == arc)
    #expect(MicrophoneAppAttribution.owner(pid: 8, bundleID: "company.thebrowser.browserOther.helper", apps: apps, ownPID: 1, ownBundleID: "work.tapas.Tapas") == nil)
    // Normalization must preserve the exclusion of our own audio activity.
    #expect(MicrophoneAppAttribution.owner(pid: 8, bundleID: "WORK.TAPAS.TAPAS.helper", apps: apps, ownPID: 1, ownBundleID: "work.tapas.Tapas") == nil)
}
