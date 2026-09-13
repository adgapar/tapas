import Testing
@testable import TapasCore

@Test func englishDropsWordsCoveredByFillerSpans() {
    let transcript = Transcript(
        words: [
            SpokenWord(text: "so", start: 0.0, end: 0.2),
            SpokenWord(text: "um", start: 0.2, end: 0.5),
            SpokenWord(text: "hello", start: 0.6, end: 1.0),
        ],
        duration: 1.0
    )
    let stripped = FillerStripper.strip(
        transcript: transcript,
        fillers: [FillerSpan(start: 0.15, end: 0.55)],
        language: "en"
    )
    #expect(stripped.words.map(\.text) == ["so", "hello"])
    #expect(stripped.text == "so hello")
}

@Test func spanishIsLeftAlone() {
    let transcript = Transcript(
        words: [SpokenWord(text: "eh", start: 0.0, end: 0.3)],
        duration: 0.3
    )
    let stripped = FillerStripper.strip(
        transcript: transcript,
        fillers: [FillerSpan(start: 0.0, end: 0.3)],
        language: "es"
    )
    #expect(stripped.words.count == 1)
}
