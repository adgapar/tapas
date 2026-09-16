import Foundation

public enum TranscriptFolders {
    /// Validate both destinations before adopting a preference. Existing files
    /// are untouched; probes have unique names and are removed immediately.
    public static func prepare(root: URL) throws {
        guard root.isFileURL else { throw CocoaError(.fileWriteInvalidFileName) }
        for name in ["dictado", "acta"] {
            let directory = root.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let probe = directory.appendingPathComponent(".tapas-write-check-\(UUID().uuidString)")
            try Data().write(to: probe, options: .withoutOverwriting)
            try FileManager.default.removeItem(at: probe)
        }
    }
}
