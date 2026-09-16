import CoreGraphics
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
