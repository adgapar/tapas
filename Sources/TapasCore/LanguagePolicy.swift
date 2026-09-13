public enum VozLanguages {
    public static let supported: Set<String> = [
        "bg", "cs", "da", "de", "el", "en", "es", "et", "fi",
        "fr", "hr", "hu", "it", "lt", "lv", "mt", "nl", "pl",
        "pt", "ro", "ru", "sk", "sl", "sv", "uk",
    ]
}

public enum LanguagePolicy {
    public static func resolve(guess: LanguageGuess, lastKnown: String?) -> String? {
        if guess.isReliable, let code = guess.language, VozLanguages.supported.contains(code) {
            return code
        }
        return lastKnown
    }
}
