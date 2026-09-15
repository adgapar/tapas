import Foundation
import Testing
@testable import TapasApp

// Sparkle's optional Objective-C hooks must match at runtime; a misspelled Swift
// method can compile while silently dropping recording protection.
@MainActor @Test func sparkleCanCallRecordingProtectionHooks() {
    let updater = AppUpdater()
    #expect(updater.responds(to: NSSelectorFromString("updater:mayPerformUpdateCheck:error:")))
    #expect(updater.responds(to: NSSelectorFromString("updater:shouldPostponeRelaunchForUpdate:untilInvokingBlock:")))
    #expect(updater.responds(to: NSSelectorFromString("updater:didAbortWithError:")))
}
