import Testing
@testable import TapasCore

@Test func transcriptJoinsWordTextsWithSpaces() {
    let t = Transcript(
        words: [
            SpokenWord(text: "hola", start: 0, end: 0.3),
            SpokenWord(text: "adi", start: 0.35, end: 0.5),
        ],
        duration: 0.5
    )
    #expect(t.text == "hola adi")
}
