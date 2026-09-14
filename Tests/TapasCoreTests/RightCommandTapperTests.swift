import Testing
@testable import TapasCore

@Test func rightCommandTapToggles() {
    var tapper = HotkeyTapper(hotkey: .rightCommand)
    #expect(tapper.handle(.down(code: 54, isRepeat: false)) == false)
    #expect(tapper.handle(.up(code: 54)) == true)
}

@Test func leftCommandDoesNotToggle() {
    var tapper = HotkeyTapper(hotkey: .rightCommand)
    #expect(tapper.handle(.down(code: 55, isRepeat: false)) == false)
    #expect(tapper.handle(.up(code: 55)) == false)
}

@Test func commandCIsNotATap() {
    var tapper = HotkeyTapper(hotkey: .rightCommand)
    _ = tapper.handle(.down(code: 54, isRepeat: false))
    _ = tapper.handle(.down(code: 8, isRepeat: false))
    #expect(tapper.handle(.up(code: 54)) == false)
}

@Test func flagsChangedOnRightCommandToggles() {
    var tapper = HotkeyTapper(hotkey: .rightCommand)
    #expect(tapper.handleFlags(code: 54, modifiers: [.command]) == false)
    #expect(tapper.handleFlags(code: 54, modifiers: []) == true)
}

@Test func flagsChangedOnLeftCommandDoesNotToggle() {
    var tapper = HotkeyTapper(hotkey: .rightCommand)
    #expect(tapper.handleFlags(code: 55, modifiers: [.command]) == false)
    #expect(tapper.handleFlags(code: 55, modifiers: []) == false)
}

@Test func controlOptionTapToggles() {
    var tapper = HotkeyTapper(hotkey: .standard)
    #expect(tapper.handleFlags(code: 59, modifiers: [.control]) == false)
    #expect(tapper.handleFlags(code: 58, modifiers: [.control, .option]) == true)
    #expect(tapper.handleFlags(code: 58, modifiers: [.control]) == false)
    #expect(tapper.handleFlags(code: 58, modifiers: [.control, .option]) == true)
}

@Test func controlOptionDoesNotRefireWhileHeld() {
    var tapper = HotkeyTapper(hotkey: .standard)
    #expect(tapper.handleFlags(code: 58, modifiers: [.control, .option]) == true)
    #expect(tapper.handleFlags(code: 58, modifiers: [.control, .option]) == false)
}

@Test func controlOptionLabelIsQuiet() {
    #expect(Hotkey.standard.label == "⌃⌥")
}

@Test func defaultHotkeyIsControlOption() {
    #expect(TapasSettings().hotkey == .standard)
}
