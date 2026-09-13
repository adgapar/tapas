import Foundation
import Testing
@testable import TapasCore

struct FakeRedactor: TextRedactor {
    func redact(_ text: String) async throws -> String {
        text.replacingOccurrences(of: "adi@orbio.work", with: "[EMAIL_1]")
    }
}

@Test func writesRedactedMarkdown() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let started = try Date("2026-09-13T14:05:00Z", strategy: .iso8601)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let writer = HistoryWriter(directory: dir, redactor: FakeRedactor(), calendar: calendar)
    let url = try await writer.write(
        HistoryRecord(
            startedAt: started,
            language: "en",
            duration: 2.5,
            pastedText: "email adi@orbio.work please"
        )
    )
    let body = try String(contentsOf: url, encoding: .utf8)
    #expect(body.contains("language: en"))
    #expect(body.contains("duration: 2.5"))
    #expect(body.contains("[EMAIL_1]"))
    #expect(!body.contains("adi@orbio.work"))
    #expect(url.lastPathComponent == "2026-09-13-1405.md")
}
