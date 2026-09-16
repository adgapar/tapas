import CoreGraphics
import Foundation
import Testing
import TapasCore
@testable import TapasApp

@Test func actaShortcutConsumesOnlyItsOwnKeySequence() {
    let monitor = HotkeyMonitor()
    #expect(!monitor.consider(type: .keyDown, code: 46, modifiers: [], isRepeat: false))
    #expect(!monitor.consider(type: .keyUp, code: 46, modifiers: [], isRepeat: false))
    #expect(monitor.consider(type: .keyDown, code: 46, modifiers: [.control, .shift], isRepeat: false))
    #expect(monitor.consider(type: .keyDown, code: 46, modifiers: [.control, .shift], isRepeat: true))
    #expect(monitor.consider(type: .keyUp, code: 46, modifiers: [], isRepeat: false))
    #expect(!monitor.consider(type: .keyDown, code: 46, modifiers: [], isRepeat: false))
}

@Test func escapeCancelsShortcutCaptureAndConsumesItsRelease() {
    let monitor = HotkeyMonitor()
    monitor.recording = true
    #expect(monitor.consider(type: .keyDown, code: 53, modifiers: [], isRepeat: false))
    #expect(!monitor.recording)
    #expect(monitor.consider(type: .keyUp, code: 53, modifiers: [], isRepeat: false))
    #expect(!monitor.consider(type: .keyDown, code: 0, modifiers: [], isRepeat: false))
}

@MainActor @Test func acceptingSuggestionWithoutPermissionsOnlyOpensControls() async {
    let controller = ActaController()
    controller.model.ready = true
    controller.permissionStatus = { (false, false) }
    var opened = 0
    controller.onShow = { opened += 1 }
    await controller.startSuggested(MicrophoneApp(pid: 1234, bundleID: "example.meeting", name: "Meeting"))
    #expect(opened == 1)
    #expect(controller.model.snapshot.phase == .idle)
    #expect(!controller.model.busy)
    #expect(!controller.model.microphoneGranted)
    #expect(!controller.model.appAudioGranted)
}

@MainActor @Test func reopeningSavedActaPreparesNextMeetingWithoutLosingSavedTranscript() {
    let controller = ActaController()
    controller.permissionStatus = { (false, false) }
    var meeting = ActaDocument(appName: "Arc")
    meeting.duration = 1_200
    meeting.segments = (0..<240).map {
        ActaSegment(start: Double($0 * 5), source: .app, text: "Meeting segment \($0)", language: "en")
    }
    controller.model.snapshot.document = meeting
    controller.model.snapshot.savedURL = URL(fileURLWithPath: "/tmp/saved-meeting.md")
    controller.model.snapshot.phase = .saved
    controller.model.showingSavedReceipt = true
    var opened = false
    controller.onShow = { opened = true }
    controller.show()
    #expect(opened)
    #expect(!controller.model.showingSavedReceipt)
    #expect(controller.model.snapshot.phase == .saved)
    #expect(controller.model.snapshot.document?.segments.count == 240)
    #expect(controller.model.snapshot.savedURL?.lastPathComponent == "saved-meeting.md")
    #expect(!controller.model.hasSession)
}
