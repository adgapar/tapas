import Foundation

public struct HistoryWriter: Sendable {
    public var directory: URL
    public var redactor: any TextRedactor
    public var calendar: Calendar

    public init(directory: URL, redactor: any TextRedactor, calendar: Calendar = .current) {
        self.directory = directory
        self.redactor = redactor
        self.calendar = calendar
    }

    public func write(_ record: HistoryRecord) async throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = Self.filename(for: record.startedAt, calendar: calendar)
        var url = directory.appendingPathComponent(name)
        let redacted = try await redactor.redact(record.pastedText)
        let iso = ISO8601DateFormatter().string(from: record.startedAt)
        let language = record.language ?? ""
        let markdown = """
        ---
        time: \(iso)
        language: \(language)
        duration: \(record.duration)
        ---

        \(redacted)
        """
        // Exclusive creation prevents both rapid takes and concurrent writers overwriting notes.
        let data = Data(markdown.utf8)
        while true {
            do {
                try data.write(to: url, options: .withoutOverwriting)
                break
            } catch CocoaError.fileWriteFileExists {
                url = directory.appendingPathComponent("\(name.dropLast(3))-\(UUID().uuidString.prefix(8)).md")
            }
        }
        return url
    }

    public static func filename(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let y = c.year ?? 0
        let mo = c.month ?? 0
        let d = c.day ?? 0
        let h = c.hour ?? 0
        let mi = c.minute ?? 0
        return String(format: "%04d-%02d-%02d-%02d%02d.md", y, mo, d, h, mi)
    }
}
