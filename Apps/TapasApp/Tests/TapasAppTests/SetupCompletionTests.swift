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

@MainActor @Test func openStageRequiresChosenFolderAndNeverStartsPracticeByAdvancing() async {
    _ = NSApplication.shared
    let controller = SetupWindowController(flow: SetupFlow(phase: .kitchen))
    var recordings = 0
    var completions = 0
    controller.onPracticeToggle = { recordings += 1 }
    controller.onFinished = { completions += 1 }
    await controller.primary()
    #expect(controller.model.stage == 2)
    controller.model.folderConfirmed = true
    await controller.primary()
    #expect(controller.model.stage == 3)
    #expect(recordings == 0)
    await controller.handleTalk()
    #expect(recordings == 0) // Models and microphone are still unavailable.
    await controller.primary()
    #expect(completions == 1)
}

@MainActor @Test func onboardingBackCannotLeaveActivePractice() {
    _ = NSApplication.shared
    let controller = SetupWindowController(flow: SetupFlow(phase: .tryIt))
    controller.model.phase = .listening
    controller.back()
    #expect(controller.model.stage == 3)
    controller.model.phase = .idle
    controller.back()
    #expect(controller.model.stage == 2)
}

@MainActor @Test func resumingSetupSkipsEntranceAndClosingCancelsPresentation() {
    _ = NSApplication.shared
    let controller = SetupWindowController(flow: SetupFlow(phase: .peek))
    #expect(!controller.model.entered)
    controller.setStage(2)
    #expect(controller.model.entered)
    controller.model.isPresented = true
    controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    #expect(!controller.model.isPresented)
    #expect(controller.model.stage == 2)
    #expect(controller.model.phase == .idle)
}

@MainActor @Test func assistantInstallationIsAvailableWithoutPracticeAndKeepsSetupOpen() async {
    _ = NSApplication.shared
    let assistant = AssistantSetupModel()
    let controller = SetupWindowController(flow: SetupFlow(phase: .tryIt), assistant: assistant)
    var completions = 0
    var actions: [String] = []
    controller.onFinished = { completions += 1 }
    controller.onAssistantAction = { action in
        actions.append(action)
        if action == "install" { assistant.status = "Installed" }
    }
    #expect(!controller.model.completedPractice)
    #expect(!controller.model.flow.modelsReady)
    controller.assistantAction("install")
    #expect(actions == ["install"])
    #expect(controller.model.assistant === assistant)
    #expect(controller.model.assistant.status == "Installed")
    #expect(controller.model.flow.phase == .tryIt)
    #expect(completions == 0)
    controller.assistantAction("templates")
    #expect(actions == ["install", "templates"])
    controller.model.phase = .listening
    controller.assistantAction("install")
    controller.assistantAction("templates")
    #expect(actions.count == 2)
    controller.model.phase = .idle
    await controller.primary()
    #expect(completions == 1)
}

@MainActor @Test func finishingWithoutAssistantInstallationOrPracticeKeepsBothOptional() async {
    _ = NSApplication.shared
    let controller = SetupWindowController(flow: SetupFlow(phase: .tryIt))
    var installations = 0
    controller.onAssistantAction = { if $0 == "install" { installations += 1 } }
    await controller.primary()
    #expect(controller.model.flow.phase == .finished)
    #expect(installations == 0)
}
