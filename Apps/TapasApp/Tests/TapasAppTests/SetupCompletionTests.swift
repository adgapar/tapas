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

@MainActor @Test func advancingWalksFiveStepsNeverStartsPracticeAndConfirmsTheShownFolder() async {
    _ = NSApplication.shared
    let controller = SetupWindowController(flow: SetupFlow(phase: .kitchen))
    var recordings = 0
    var completions = 0
    var defaultFolders = 0
    controller.onPracticeToggle = { recordings += 1 }
    controller.onFinished = { completions += 1 }
    controller.defaultFolder = { defaultFolders += 1 }
    #expect(controller.model.stage == 0)
    for expected in 1...4 {
        await controller.primary()
        #expect(controller.model.stage == expected)
    }
    #expect(recordings == 0)
    await controller.handleTalk()
    #expect(recordings == 0) // Practice belongs to the First take step, with models and microphone.
    await controller.primary()
    #expect(completions == 1)
    #expect(defaultFolders == 1) // Starting confirms the folder the House rules step showed.
    #expect(controller.model.folderConfirmed)
}

@MainActor @Test func stepNamesOnlyReturnToStepsAlreadyReached() {
    _ = NSApplication.shared
    let controller = SetupWindowController(flow: SetupFlow(phase: .peek))
    controller.setStage(2)
    controller.goTo(4)
    #expect(controller.model.stage == 2)
    controller.goTo(0)
    #expect(controller.model.stage == 0)
}

@MainActor @Test func onboardingBackCannotLeaveActivePractice() {
    _ = NSApplication.shared
    let controller = SetupWindowController(flow: SetupFlow(phase: .tryIt))
    #expect(controller.model.stage == 2)
    controller.model.phase = .listening
    controller.back()
    #expect(controller.model.stage == 2)
    controller.model.phase = .idle
    controller.back()
    #expect(controller.model.stage == 1)
}

@MainActor @Test func resumingSetupSkipsEntranceAndClosingCancelsPresentation() {
    _ = NSApplication.shared
    let controller = SetupWindowController(flow: SetupFlow(phase: .peek))
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
    controller.setStage(SetupWindowController.lastStage)
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
    controller.onAssistantAction = { if $0.hasPrefix("install") { installations += 1 } }
    controller.setStage(SetupWindowController.lastStage)
    await controller.primary()
    #expect(controller.model.flow.phase == .finished)
    #expect(installations == 0)
}
