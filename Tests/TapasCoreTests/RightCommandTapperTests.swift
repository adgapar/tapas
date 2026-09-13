import Testing
@testable import TapasCore

@Test func rightCommandTapToggles() {
    var tapper = RightCommandTapper()
    #expect(tapper.handle(.down(code: 54, isRepeat: false)) == false)
    #expect(tapper.handle(.up(code: 54)) == true)
}

@Test func leftCommandDoesNotToggle() {
    var tapper = RightCommandTapper()
    #expect(tapper.handle(.down(code: 55, isRepeat: false)) == false)
    #expect(tapper.handle(.up(code: 55)) == false)
}

@Test func commandCIsNotATap() {
    var tapper = RightCommandTapper()
    _ = tapper.handle(.down(code: 54, isRepeat: false))
    _ = tapper.handle(.down(code: 8, isRepeat: false))
    #expect(tapper.handle(.up(code: 54)) == false)
}
