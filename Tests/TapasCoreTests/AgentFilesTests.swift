import Foundation
import Testing
@testable import TapasCore

private struct LibraryFixture {
    let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
    func prepare() throws { try TranscriptFolders.prepare(root: root) }
    func cleanup() { try? FileManager.default.removeItem(at: root) }
    func write(_ path: String, _ text: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }
    func read(_ path: String) throws -> String { try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8) }
}

@Test func metadataUsesStableIDsAndSavedRedactedText() async throws {
    let fixture = LibraryFixture(); defer { fixture.cleanup() }
    try fixture.prepare()
    let record = HistoryRecord(startedAt: Date(timeIntervalSince1970: 0), language: "en", duration: 2.5, pastedText: "email adi@orbio.work")
    let writer = HistoryWriter(directory: fixture.root.appendingPathComponent("dictado"), redactor: FakeRedactor())
    let first = try await writer.write(record)
    let second = try await writer.write(record)
    let text = try String(contentsOf: first, encoding: .utf8)
    let fields = TranscriptMetadata.split(text).fields
    #expect(fields["id"] == record.id.uuidString)
    #expect(fields["duration_seconds"] == "2.5")
    #expect(fields["redaction"] == "applied")
    #expect(TranscriptMetadata.split(try String(contentsOf: second, encoding: .utf8)).fields["id"] == fields["id"])
    let report = await TranscriptIndex().rebuild(root: fixture.root)
    #expect(report.warnings.isEmpty)
    #expect(!(try fixture.read("INDEX.md")).contains("adi@orbio.work"))
    #expect(try fixture.read("INDEX.md").contains("EMAIL"))
}

@Test func rebuildPreservesTranscriptsAndHandlesMovesDeletesAndCustomTitles() async throws {
    let fixture = LibraryFixture(); defer { fixture.cleanup() }
    try fixture.prepare()
    let source = "---\ntime: 2026-09-16T12:00:00Z\nduration: 60\ntitle: \"Release [notes]\"\n---\n\nSpecific onboarding discussion."
    try fixture.write("acta/one.md", source)
    try fixture.write("dictado/unknown.md", "Older note without metadata.")
    let indexer = TranscriptIndex()
    let first = await indexer.rebuild(root: fixture.root)
    #expect(first.recordings == 2)
    #expect(first.warnings.isEmpty)
    let index = try fixture.read("INDEX.md")
    #expect(index.contains("Release \\[notes\\]"))
    #expect(index.contains("unknown-date.md"))
    #expect(try fixture.read("acta/one.md") == source)
    _ = await indexer.rebuild(root: fixture.root)
    #expect(try fixture.read("INDEX.md") == index)
    try FileManager.default.moveItem(at: fixture.root.appendingPathComponent("acta/one.md"), to: fixture.root.appendingPathComponent("acta/moved #1.md"))
    _ = await indexer.rebuild(root: fixture.root)
    #expect(try fixture.read("INDEX.md").contains("acta/moved%20%231.md"))
    #expect(!(try fixture.read("INDEX.md")).contains("acta/one.md"))
    try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("acta/moved #1.md"))
    _ = await indexer.rebuild(root: fixture.root)
    #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("indexes/2026-09.md").path))
}

@Test func boundedIndexesSortByInstantAndRetainAllArchiveEntries() async throws {
    let fixture = LibraryFixture(); defer { fixture.cleanup() }
    try fixture.prepare()
    for n in 0..<205 { try fixture.write("dictado/\(n).md", "---\ntime: 2026-09-01T00:00:00Z\n---\nWords \(n)") }
    try fixture.write("dictado/earlier.md", "---\ntime: 2026-09-16T14:00:00+02:00\n---\nEarlier")
    try fixture.write("dictado/later.md", "---\ntime: 2026-09-16T13:00:00.100Z\n---\nLater")
    let report = await TranscriptIndex().rebuild(root: fixture.root)
    #expect(report.recordings == 207)
    let index = try fixture.read("INDEX.md")
    #expect(index.components(separatedBy: "Preview:").count - 1 == 50)
    #expect(index.range(of: "dictado/later.md")!.lowerBound < index.range(of: "dictado/earlier.md")!.lowerBound)
    #expect(try fixture.read("indexes/2026-09.md").components(separatedBy: "Preview:").count - 1 == 200)
    #expect(try fixture.read("indexes/2026-09-2.md").components(separatedBy: "Preview:").count - 1 == 7)
}

@Test func indexConflictsNeverOverwriteUserContentOrBreakSaves() async throws {
    let fixture = LibraryFixture(); defer { fixture.cleanup() }
    try fixture.prepare()
    try fixture.write("INDEX.md", "My own index")
    try fixture.write("SCHEMA.md", "My own schema")
    let writer = HistoryWriter(directory: fixture.root.appendingPathComponent("dictado"), redactor: FakeRedactor())
    let saved = try await writer.write(HistoryRecord(startedAt: Date(), language: "en", duration: 1, pastedText: "Saved words"))
    let report = await TranscriptIndex().rebuild(root: fixture.root)
    #expect(report.warnings.count == 2)
    #expect(FileManager.default.fileExists(atPath: saved.path))
    #expect(try fixture.read("INDEX.md") == "My own index")
    #expect(try fixture.read("SCHEMA.md") == "My own schema")
}

@Test func editedGeneratedPagesAndAssistantArtifactsSurviveRebuild() async throws {
    let fixture = LibraryFixture(); defer { fixture.cleanup() }
    try fixture.prepare()
    let indexer = TranscriptIndex()
    _ = await indexer.rebuild(root: fixture.root)
    let edited = try fixture.read("INDEX.md") + "\nUser addition\n"
    try fixture.write("INDEX.md", edited)
    try fixture.write("indexes/project.md", "Assistant project index")
    let report = await indexer.rebuild(root: fixture.root)
    #expect(!report.warnings.isEmpty)
    #expect(try fixture.read("INDEX.md") == edited)
    #expect(try fixture.read("indexes/project.md") == "Assistant project index")
}

@Test func linkedIndexCannotModifyItsTarget() async throws {
    let fixture = LibraryFixture(); defer { fixture.cleanup() }
    try fixture.prepare()
    try fixture.write("outside.md", "Keep me")
    try FileManager.default.createSymbolicLink(at: fixture.root.appendingPathComponent("INDEX.md"), withDestinationURL: fixture.root.appendingPathComponent("outside.md"))
    let report = await TranscriptIndex().rebuild(root: fixture.root)
    #expect(!report.warnings.isEmpty)
    #expect(try fixture.read("outside.md") == "Keep me")
}

@Test func libraryLocationTracksPreviousRootsWithoutMovingFiles() throws {
    let fixture = LibraryFixture(); defer { fixture.cleanup() }
    try fixture.prepare()
    let config = LibraryLocation.file(home: fixture.root)
    let first = fixture.root.appendingPathComponent("old")
    let next = fixture.root.appendingPathComponent("new")
    try LibraryLocation.update(root: first, at: config)
    let value = try LibraryLocation.update(root: next, at: config)
    #expect(value.current_root == next.path)
    #expect(value.previous_roots == [first.path])
    let back = try LibraryLocation.update(root: first, at: config)
    #expect(back.previous_roots == [next.path])
    #expect(!FileManager.default.fileExists(atPath: next.path))
    try Data("custom".utf8).write(to: config)
    #expect(throws: (any Error).self) { try LibraryLocation.update(root: first, at: config) }
    #expect(try String(contentsOf: config, encoding: .utf8) == "custom")
}

@Test(arguments: AssistantHost.allCases) func skillInstallUpdateRemoveIsOwnedAndReusesCursorDiscovery(host: AssistantHost) throws {
    let fixture = LibraryFixture(); defer { fixture.cleanup() }
    let installer = AssistantSkill(home: fixture.root)
    #expect(installer.status(for: host) == "Not installed")
    let directory = try installer.install(for: host)
    #expect(installer.status(for: host) == "Installed")
    #expect(try installer.install(for: .cursor).path == directory.path)
    #expect(try installer.install(for: host).path == directory.path)
    try Data("extra".utf8).write(to: directory.appendingPathComponent("custom.md"))
    try installer.remove(for: host)
    #expect(try String(contentsOf: directory.appendingPathComponent("custom.md"), encoding: .utf8) == "extra")
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("SKILL.md").path))
}

@Test func editedOrForeignSkillsAreNeverUpdatedOrRemoved() throws {
    let fixture = LibraryFixture(); defer { fixture.cleanup() }
    let installer = AssistantSkill(home: fixture.root)
    let directory = try installer.install(for: .codex)
    let file = directory.appendingPathComponent("SKILL.md")
    try Data("My edited skill".utf8).write(to: file)
    #expect(throws: (any Error).self) { try installer.install(for: .codex) }
    #expect(throws: (any Error).self) { try installer.remove(for: .codex) }
    #expect(try String(contentsOf: file, encoding: .utf8) == "My edited skill")
    try installer.install(for: .claude)
    #expect(installer.status(for: .claude) == "Installed")
    #expect(try String(contentsOf: file, encoding: .utf8) == "My edited skill")
}

@Test func managedSkillUpdateChecksOldContentsAndPreservesAdditionalFiles() throws {
    let fixture = LibraryFixture(); defer { fixture.cleanup() }
    let installer = AssistantSkill(home: fixture.root)
    let directory = try installer.install(for: .claude)
    let old = Data("---\nname: tapas\ndescription: Old skill\n---\nOld instructions".utf8)
    try old.write(to: directory.appendingPathComponent("SKILL.md"))
    try Data(ManagedDocument.digest(old).utf8).write(to: directory.appendingPathComponent(".tapas-skill.sha256"))
    #expect(installer.status(for: .claude) == "Update available")
    try installer.install(for: .claude)
    #expect(installer.status(for: .claude) == "Installed")
}

@Test(arguments: [AssistantHost.claude, .codex]) func claudeAndCodexInstallationsCoexistAndAreManagedIndependently(first: AssistantHost) throws {
    let fixture = LibraryFixture(); defer { fixture.cleanup() }
    let installer = AssistantSkill(home: fixture.root)
    let second: AssistantHost = first == .claude ? .codex : .claude
    let firstDirectory = try installer.install(for: first)
    let secondDirectory = try installer.install(for: second)
    #expect(firstDirectory.path != secondDirectory.path)
    #expect(installer.status(for: first) == "Installed")
    #expect(installer.status(for: second) == "Installed")
    let cursor = try installer.install(for: .cursor)
    #expect(cursor.path == fixture.root.appendingPathComponent(".agents/skills/tapas").path)
    #expect(!FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent(".cursor/skills/tapas").path))
    try installer.install(for: first)
    try installer.remove(for: first)
    #expect(installer.status(for: first) == "Not installed")
    #expect(installer.status(for: second) == "Installed")
    #expect(try installer.install(for: .cursor).path == secondDirectory.path)
    try installer.remove(for: second)
    #expect(installer.status(for: second) == "Not installed")
}
