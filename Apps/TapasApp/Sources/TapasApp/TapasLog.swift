import Foundation

func tapasLog(_ message: String) {
    let line = "\(Date()) \(message)\n"
    NSLog("Tapas %@", message)
    let url = URL(fileURLWithPath: "/tmp/tapas.log")
    guard let data = line.data(using: .utf8) else { return }
    if FileManager.default.fileExists(atPath: url.path) {
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(data)
    } else {
        try? data.write(to: url)
    }
}
