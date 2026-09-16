import Foundation
import CryptoKit

/// Ownership includes a content checksum: editing a generated page relinquishes ownership.
enum ManagedDocument {
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func render(_ body: String) -> Data {
        Data(("<!-- tapas-generated:v1 sha256=\(digest(Data(body.utf8))) -->\n" + body).utf8)
    }
    static func isOwned(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8), let newline = text.firstIndex(of: "\n") else { return false }
        return render(String(text[text.index(after: newline)...])) == data
    }
    static func exists(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }
    static func checkPath(_ url: URL) throws {
        var part = url.standardizedFileURL
        while part.path != "/" {
            // Foundation normalizes /private/var back to /var on macOS. These
            // OS-owned aliases are safe; user-controlled symlinks are not.
            if ["/var", "/tmp", "/etc"].contains(part.path),
               (try? FileManager.default.destinationOfSymbolicLink(atPath: part.path)) == "private" + part.path { return }
            if let attributes = try? FileManager.default.attributesOfItem(atPath: part.path),
               attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                throw LibraryFileError.conflict(part.path)
            }
            part.deleteLastPathComponent()
        }
    }
    static func write(_ body: String, to url: URL) throws {
        try checkPath(url)
        let bytes = render(body)
        if exists(url) {
            let old = try Data(contentsOf: url)
            guard isOwned(old) else { throw LibraryFileError.conflict(url.path) }
            if old == bytes { return }
            try bytes.write(to: url, options: .atomic)
        } else {
            try bytes.write(to: url, options: .withoutOverwriting)
        }
    }
}

public enum LibraryFileError: LocalizedError {
    case conflict(String)
    public var errorDescription: String? {
        switch self { case .conflict(let path): "Tapas left an existing, edited, or linked file unchanged: \(path). Move it aside to let Tapas create its own copy." }
    }
}
