import Testing
@testable import TapasCore

private let browser = MicrophoneApp(pid: 42, bundleID: "browser", name: "Browser")

@Test func meetingEndsAfterSustainedInactivityEvenIfAnotherAppUsesTheMic() {
    var policy = MeetingEndPolicy(app: browser)
    let other = MicrophoneApp(pid: 43, bundleID: "other", name: "Other")
    #expect(policy.shouldFinish(activeApps: [browser], now: 0) == false)
    for time in 1...30 {
        #expect(policy.shouldFinish(activeApps: [other], now: Double(time)) == false)
    }
    #expect(policy.shouldFinish(activeApps: [other], now: 31) == true)
}

@Test func meetingMicReconnectResetsEndTimer() {
    var policy = MeetingEndPolicy(app: browser)
    for time in 0...29 { #expect(policy.shouldFinish(activeApps: [], now: Double(time)) == false) }
    #expect(policy.shouldFinish(activeApps: [browser], now: 30) == false)
    for time in 31...60 { #expect(policy.shouldFinish(activeApps: [], now: Double(time)) == false) }
    #expect(policy.shouldFinish(activeApps: [], now: 61) == true)
}

@Test func meetingDetectionFailureAndSleepDoNotCountAsInactivity() {
    var policy = MeetingEndPolicy(app: browser)
    for time in 0...29 { #expect(policy.shouldFinish(activeApps: [], now: Double(time)) == false) }
    #expect(policy.shouldFinish(activeApps: nil, now: 30) == false)
    #expect(policy.shouldFinish(activeApps: [], now: 31) == false)
    #expect(policy.shouldFinish(activeApps: [], now: 300) == false)
    for time in 301...329 { #expect(policy.shouldFinish(activeApps: [], now: Double(time)) == false) }
    #expect(policy.shouldFinish(activeApps: [], now: 330) == true)
}

@Test func restartedBrowserDoesNotKeepTheOldMeetingAlive() {
    var policy = MeetingEndPolicy(app: browser)
    let restarted = MicrophoneApp(pid: 99, bundleID: browser.bundleID, name: browser.name)
    for time in 0...29 { #expect(policy.shouldFinish(activeApps: [restarted], now: Double(time)) == false) }
    #expect(policy.shouldFinish(activeApps: [restarted], now: 30) == true)
}
