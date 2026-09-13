public enum FillerStripper {
    public static func strip(transcript: Transcript, fillers: [FillerSpan], language: String?) -> Transcript {
        guard language == "en", !fillers.isEmpty else { return transcript }
        let kept = transcript.words.filter { word in
            let mid = (word.start + word.end) / 2
            return !fillers.contains { mid >= $0.start && mid <= $0.end }
        }
        return Transcript(words: kept, duration: transcript.duration)
    }
}
