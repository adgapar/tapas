import Foundation

public struct HistoryEntry: Identifiable, Equatable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let date: Date
    public let text: String
    public let markdown: String
    public var title: String { String(text.split(separator: "\n").first.map(String.init)?.prefix(72) ?? "Untitled take") }
}

public enum HistoryLibrary {
    public static func read(directory: URL) throws -> [HistoryEntry] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey], options: [.skipsHiddenFiles])
        return urls.filter { $0.pathExtension.lowercased() == "md" }.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true, let markdown = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let text: String
            if markdown.hasPrefix("---\n"), let end = markdown.range(of: "\n---\n", range: markdown.index(markdown.startIndex, offsetBy: 4)..<markdown.endIndex) {
                text = String(markdown[end.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else { text = markdown.trimmingCharacters(in: .whitespacesAndNewlines) }
            return HistoryEntry(url: url, date: values.contentModificationDate ?? .distantPast, text: text, markdown: markdown)
        }.sorted { $0.date > $1.date }
    }
}
