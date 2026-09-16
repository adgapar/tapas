import AppKit
import TapasCore

@main
enum Tapas {
    nonisolated(unsafe) static var delegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let arguments = CommandLine.arguments
        if arguments.count >= 2, arguments[1] == "--install-skill" {
            guard arguments.count == 3, let host = AssistantHost(rawValue: arguments[2]) else {
                fputs("Usage: Tapas --install-skill claude|codex|cursor\n", stderr); exit(2)
            }
            do {
                // Use the last location published by the GUI; command-line defaults
                // can have a different bundle domain from the running app.
                guard FileManager.default.fileExists(atPath: LibraryLocation.file().path) else {
                    fputs("Open Tapas once to publish your transcript folder, then retry.\n", stderr); exit(1)
                }
                let location = try JSONDecoder().decode(LibraryLocation.self, from: Data(contentsOf: LibraryLocation.file()))
                guard location.schema_version == 1 else { throw CocoaError(.fileReadCorruptFile) }
                try AssistantWorkflows.prepare(root: URL(fileURLWithPath: location.current_root, isDirectory: true))
                let directory = try AssistantSkill().install(for: host)
                print("Installed at \(directory.path). Start a new assistant session.")
            } catch { fputs("Skill installation failed: \(error.localizedDescription)\n", stderr); exit(1) }
            return
        }
        if arguments.count == 3, arguments[1] == "--export-icon" {
            do { try DesignRendering.exportIcon(to: URL(fileURLWithPath: arguments[2], isDirectory: true)) }
            catch { fputs("Icon export failed: \(error)\n", stderr); exit(1) }
            return
        }
        #if DEBUG
        if arguments.count == 2, arguments[1] == "--prepare-models" {
            Task { @MainActor in
                do {
                    let catalog = DesertCatalog()
                    fputs("Preparing local Dictado models…\n", stderr)
                    try await catalog.download()
                    _ = try await makeVoz()
                    print("Models ready.")
                    exit(0)
                } catch { fputs("Model preparation failed: \(error)\n", stderr); exit(1) }
            }
            app.run()
            return
        }
        if arguments.count == 4, arguments[1] == "--verify-dictado" {
            Task { @MainActor in
                do {
                    try await DictadoVerification.run(audio: URL(fileURLWithPath: arguments[2]), historyDirectory: URL(fileURLWithPath: arguments[3], isDirectory: true))
                    exit(0)
                } catch { fputs("Dictado verification failed: \(error)\n", stderr); exit(1) }
            }
            app.run()
            return
        }
        if arguments.count == 3, arguments[1] == "--render-design" {
            do { try DesignRendering.renderViews(to: URL(fileURLWithPath: arguments[2], isDirectory: true)) }
            catch { fputs("Design render failed: \(error)\n", stderr); exit(1) }
            return
        }
        #endif
        let delegate = AppDelegate()
        self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
