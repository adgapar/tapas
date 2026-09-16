import Foundation

/// The YAML subset emitted by Tapas uses scalar values and flow arrays.
public enum TranscriptMetadata {
    public static func frontmatter(id: UUID, tool: String, startedAt: Date, duration: Double,
                                   languages: [String], redaction: String, sources: [String]) -> String {
        let seconds = duration.isFinite ? max(0, duration) : 0
        return """
        ---
        schema_version: 1
        id: \(id.uuidString)
        tool: \(tool)
        time: \(ISO8601DateFormatter().string(from: startedAt))
        duration_seconds: \(seconds)
        duration: \(seconds)
        languages: [\(languages.sorted().map(quote).joined(separator: ", "))]
        redaction: \(redaction)
        speaker_labeling: \(tool == "acta" ? "audio_source" : "none")
        audio_sources: [\(sources.sorted().map(quote).joined(separator: ", "))]
        """
    }

    public static func quote(_ value: String) -> String {
        String(data: try! JSONEncoder().encode(value), encoding: .utf8)!
    }

    public static func split(_ markdown: String) -> (fields: [String: String], body: String) {
        let text = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard text.hasPrefix("---\n"), let end = text.range(of: "\n---\n", range: text.index(text.startIndex, offsetBy: 4)..<text.endIndex) else {
            return ([:], text)
        }
        var fields: [String: String] = [:]
        for line in text[text.index(text.startIndex, offsetBy: 4)..<end.lowerBound].split(separator: "\n") {
            guard !line.hasPrefix(" "), !line.hasPrefix("\t"), let colon = line.firstIndex(of: ":") else { continue }
            fields[String(line[..<colon])] = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        return (fields, String(text[end.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func scalar(_ value: String?) -> String? {
        guard let value, !value.isEmpty, !["null", "~", "|", ">"].contains(value) else { return nil }
        if value.hasPrefix("\"") { return try? JSONDecoder().decode(String.self, from: Data(value.utf8)) }
        if value.hasPrefix("'"), value.hasSuffix("'") { return String(value.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'") }
        return value.components(separatedBy: " #").first
    }
}
