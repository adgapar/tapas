import AppKit
import TapasCore

@MainActor
final class MenuBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settings: TapasSettings
    var onQuit: (() -> Void)?
    var onRevealHistory: (() -> Void)?
    var onSetup: (() -> Void)?
    var onPickHotkey: ((Hotkey) -> Void)?
    var onRecordHotkey: (() -> Void)?
    var hotkeyLabel: () -> String = { Hotkey.standard.label }

    init(settings: TapasSettings) {
        self.settings = settings
        super.init()
        item.button?.title = "Tapas"
        item.menu = makeMenu()
    }

    func refreshHistory() {
        item.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let files = recentFiles()
        if files.isEmpty {
            menu.addItem(withTitle: "No dictations yet", action: nil, keyEquivalent: "")
        } else {
            for url in files {
                let entry = NSMenuItem(title: url.deletingPathExtension().lastPathComponent, action: #selector(openFile(_:)), keyEquivalent: "")
                entry.target = self
                entry.representedObject = url
                menu.addItem(entry)
            }
        }
        menu.addItem(.separator())
        let setupItem = NSMenuItem(title: "Setup…", action: #selector(openSetup), keyEquivalent: "")
        setupItem.target = self
        menu.addItem(setupItem)
        let hotkeyItem = NSMenuItem(title: "Hotkey: \(hotkeyLabel())", action: nil, keyEquivalent: "")
        let hotkeyMenu = NSMenu()
        let controlOption = NSMenuItem(title: "Control-Option", action: #selector(pickControlOption), keyEquivalent: "")
        controlOption.target = self
        hotkeyMenu.addItem(controlOption)
        let rightCommand = NSMenuItem(title: "Right Command", action: #selector(pickRightCommand), keyEquivalent: "")
        rightCommand.target = self
        hotkeyMenu.addItem(rightCommand)
        let record = NSMenuItem(title: "Press a new shortcut…", action: #selector(recordHotkey), keyEquivalent: "")
        record.target = self
        hotkeyMenu.addItem(record)
        hotkeyItem.submenu = hotkeyMenu
        menu.addItem(hotkeyItem)
        let overlayOn = UserDefaults.standard.object(forKey: "overlayEnabled") as? Bool ?? false
        let overlay = NSMenuItem(title: "Overlay", action: #selector(toggleOverlay(_:)), keyEquivalent: "")
        overlay.target = self
        overlay.state = overlayOn ? .on : .off
        menu.addItem(overlay)
        let folder = NSMenuItem(title: "History folder", action: #selector(revealHistory), keyEquivalent: "")
        folder.target = self
        menu.addItem(folder)
        let about = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Tapas", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    private func recentFiles() -> [URL] {
        let dir = settings.historyDirectory
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return files
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .prefix(8)
            .map { $0 }
    }

    @objc private func openFile(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleOverlay(_ sender: NSMenuItem) {
        let overlayOn = UserDefaults.standard.object(forKey: "overlayEnabled") as? Bool ?? false
        UserDefaults.standard.set(!overlayOn, forKey: "overlayEnabled")
        sender.state = overlayOn ? .off : .on
    }

    @objc private func openSetup() {
        onSetup?()
    }

    @objc private func pickControlOption() {
        onPickHotkey?(.standard)
    }

    @objc private func pickRightCommand() {
        onPickHotkey?(.rightCommand)
    }

    @objc private func recordHotkey() {
        onRecordHotkey?()
    }

    @objc private func revealHistory() {
        onRevealHistory?()
        NSWorkspace.shared.open(settings.historyDirectory)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Tapas"
        alert.informativeText = "Dictado types what you say, on this Mac.\n\nPowered by Desert Ant Labs"
        alert.addButton(withTitle: "Desert Ant Labs")
        alert.addButton(withTitle: "OK")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "https://desertant.com") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func quit() {
        onQuit?()
        NSApp.terminate(nil)
    }
}
