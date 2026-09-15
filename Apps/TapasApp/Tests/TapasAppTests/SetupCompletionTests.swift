import AppKit
import TapasCore
import Testing
@testable import TapasApp

@MainActor @Test func closingFinishedSetupRecordsCompletionWithoutFinalButton() {
    _ = NSApplication.shared
    let controller = SetupWindowController(flow: SetupFlow(phase: .finished))
    var completions = 0
    var dismissals = 0
    controller.onFinished = { completions += 1 }
    controller.onDismissed = { dismissals += 1 }
    controller.reportCompletionIfNeeded()
    controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    #expect(completions == 1)
    #expect(dismissals == 1)
}

@MainActor @Test func postponingSetupDoesNotClaimPreparationIsComplete() {
    _ = NSApplication.shared
    let controller = SetupWindowController(flow: SetupFlow(phase: .kitchen))
    var completed = false
    var dismissed = false
    controller.onFinished = { completed = true }
    controller.onDismissed = { dismissed = true }
    controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    #expect(!completed)
    #expect(dismissed)
}
