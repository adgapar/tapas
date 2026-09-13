import Testing
@testable import TapasCore

@Test func reliableSupportedLanguageWins() {
    let guess = LanguageGuess(language: "es", isReliable: true)
    #expect(LanguagePolicy.resolve(guess: guess, lastKnown: "en") == "es")
}

@Test func unreliableFallsBackToLastKnown() {
    let guess = LanguageGuess(language: "es", isReliable: false)
    #expect(LanguagePolicy.resolve(guess: guess, lastKnown: "en") == "en")
}

@Test func unsupportedLanguageFallsBackToLastKnown() {
    let guess = LanguageGuess(language: "kk", isReliable: true)
    #expect(LanguagePolicy.resolve(guess: guess, lastKnown: "ru") == "ru")
}

@Test func nothingKnownReturnsNilAndStillAllowsTranscribe() {
    let guess = LanguageGuess(language: nil, isReliable: false)
    #expect(LanguagePolicy.resolve(guess: guess, lastKnown: nil) == nil)
}
