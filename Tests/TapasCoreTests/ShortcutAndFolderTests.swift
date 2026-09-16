import Foundation
import Testing
@testable import TapasCore

@Test func shortcutRecorderWaitsForLetterOrModifierRelease() {
    var capture = HotkeyCapture()
    #expect(capture.flagsChanged(code: 59, modifiers: .control) == nil)
    #expect(capture.flagsChanged(code: 56, modifiers: [.control, .shift]) == nil)
    #expect(capture.keyDown(code: 46, modifiers: [.control, .shift]) == .actaStandard)
    #expect(capture.flagsChanged(code: 59, modifiers: []) == nil)
    #expect(capture.flagsChanged(code: 59, modifiers: [.control, .option]) == nil)
    #expect(capture.flagsChanged(code: 58, modifiers: []) == .standard)
}

@Test func shortcutConflictsIncludeModifierOnlyPrefixes() {
    #expect(!Hotkey.standard.conflicts(with: .actaStandard))
    #expect(Hotkey.standard.conflicts(with: Hotkey(keyCode: 46, modifiers: [.control, .option, .shift])))
    #expect(Hotkey.rightCommand.conflicts(with: Hotkey(keyCode: 46, modifiers: [.command, .shift])))
    #expect(Hotkey.actaStandard.isActaShortcut)
    #expect(!Hotkey.standard.isActaShortcut)
    #expect(!Hotkey(keyCode: 53, modifiers: [.control, .shift]).isActaShortcut)
}

@Test func folderValidationCreatesBothDestinationsAndPreservesFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try TranscriptFolders.prepare(root: root)
    let file = root.appendingPathComponent("acta/keep.md")
    try Data("keep".utf8).write(to: file)
    try TranscriptFolders.prepare(root: root)
    #expect(try String(contentsOf: file, encoding: .utf8) == "keep")
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("dictado").path).isEmpty)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("acta").path) == ["keep.md"])
    #expect(throws: (any Error).self) { try TranscriptFolders.prepare(root: file) }
}
