import Foundation

/// Starter documents become user-owned as soon as they are copied into a library.
public enum AssistantWorkflows {
    @discardableResult
    public static func prepare(root: URL) throws -> URL {
        for folder in ["templates", "playbooks"] {
            let destination = root.appendingPathComponent(folder, isDirectory: true)
            try ManagedDocument.checkPath(destination)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            guard let source = Bundle.module.url(forResource: folder, withExtension: nil, subdirectory: "tapas") else {
                throw CocoaError(.fileNoSuchFile)
            }
            for file in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
                where file.pathExtension == "md" {
                let target = destination.appendingPathComponent(file.lastPathComponent)
                try ManagedDocument.checkPath(target)
                guard !ManagedDocument.exists(target) else { continue }
                try Data(contentsOf: file).write(to: target, options: .withoutOverwriting)
            }
        }
        return root.appendingPathComponent("templates", isDirectory: true)
    }
}
