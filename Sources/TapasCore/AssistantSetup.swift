import Foundation

public struct LibraryLocation: Codable, Equatable, Sendable {
    public var schema_version = 1
    public var current_root: String
    public var previous_roots: [String]

    public static func file(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support/Tapas/library.json")
    }

    @discardableResult public static func update(root: URL, at url: URL = file()) throws -> LibraryLocation {
        try ManagedDocument.checkPath(url)
        let previous: LibraryLocation?
        if ManagedDocument.exists(url) {
            previous = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
            guard previous?.schema_version == 1 else { throw LibraryFileError.conflict(url.path) }
        } else { previous = nil }
        let path = root.standardizedFileURL.path
        var older = previous?.previous_roots ?? []
        if let old = previous?.current_root, old != path, !older.contains(old) { older.append(old) }
        older.removeAll { $0 == path }
        let value = Self(current_root: path, previous_roots: older)
        if value == previous { return value }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(value).write(to: url, options: .atomic)
        return value
    }
}

public enum AssistantHost: String, CaseIterable, Identifiable, Sendable {
    case claude, codex, cursor
    public var id: String { rawValue }
    public var label: String {
        switch self { case .claude: "Claude Code"; case .codex: "Codex"; case .cursor: "Cursor" }
    }
}

public struct AssistantSkill: Sendable {
    public var home: URL
    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) { self.home = home }
    public static var content: String {
        get throws {
            guard let url = Bundle.module.url(forResource: "SKILL", withExtension: "md", subdirectory: "tapas") else { throw CocoaError(.fileNoSuchFile) }
            return try String(contentsOf: url, encoding: .utf8)
        }
    }
    private var locations: [URL] {
        [".agents", ".claude", ".cursor", ".codex"].map { home.appendingPathComponent("\($0)/skills/tapas") }
    }
    private func directory(for host: AssistantHost) -> URL {
        switch host {
        case .claude: return locations[1]
        case .codex: return locations[0]
        case .cursor:
            // Reuse a compatible copy instead of adding another one for Cursor.
            // Other assistants manage their own installations independently.
            return locations.first { ManagedDocument.exists($0) } ?? locations[0]
        }
    }
    public func status(for host: AssistantHost) -> String {
        do {
            let directory = directory(for: host)
            guard ManagedDocument.exists(directory) else { return "Not installed" }
            try verify(directory)
            return try String(contentsOf: directory.appendingPathComponent("SKILL.md"), encoding: .utf8) == Self.content ? "Installed" : "Update available"
        } catch { return error.localizedDescription }
    }
    private func verify(_ directory: URL) throws {
        try ManagedDocument.checkPath(directory)
        let skill = directory.appendingPathComponent("SKILL.md")
        let receipt = directory.appendingPathComponent(".tapas-skill.sha256")
        try ManagedDocument.checkPath(skill); try ManagedDocument.checkPath(receipt)
        guard let hash = try? String(contentsOf: receipt, encoding: .utf8),
              let bytes = try? Data(contentsOf: skill), hash == ManagedDocument.digest(bytes) else {
            throw LibraryFileError.conflict(directory.path)
        }
    }
    @discardableResult public func install(for host: AssistantHost) throws -> URL {
        let directory = directory(for: host)
        try ManagedDocument.checkPath(directory)
        if ManagedDocument.exists(directory) { try verify(directory) }
        else { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        let bytes = Data(try Self.content.utf8)
        try bytes.write(to: directory.appendingPathComponent("SKILL.md"), options: .atomic)
        try Data(ManagedDocument.digest(bytes).utf8).write(to: directory.appendingPathComponent(".tapas-skill.sha256"), options: .atomic)
        return directory
    }
    public func remove(for host: AssistantHost) throws {
        let directory = directory(for: host)
        guard ManagedDocument.exists(directory) else { return }
        try verify(directory)
        // Preserve any unrelated files the user added to this directory.
        try FileManager.default.removeItem(at: directory.appendingPathComponent("SKILL.md"))
        try FileManager.default.removeItem(at: directory.appendingPathComponent(".tapas-skill.sha256"))
        if try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty { try FileManager.default.removeItem(at: directory) }
    }
    public static func setupCommand(executable: URL, host: AssistantHost) -> String {
        "'" + executable.path.replacingOccurrences(of: "'", with: "'\\''") + "' --install-skill " + host.rawValue
    }
}
