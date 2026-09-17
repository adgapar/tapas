import AppKit
import SwiftUI
import TapasCore

@MainActor
final class MeetingPromptController {
    var enabled = true {
        didSet { if !enabled { dismiss(); onAvailability(nil) } }
    }
    var canPrompt: () -> Bool = { false }
    var isReady: () -> Bool = { false }
    var actaInProgress: () -> Bool = { false }
    var onStart: (MicrophoneApp) -> Void = { _ in }
    var onAvailability: (String?) -> Void = { _ in }
    var monitorsMeeting: () -> Bool = { false }
    var onActivity: ([MicrophoneApp]?, TimeInterval) async -> Void = { _, _ in }
    private var policy = MeetingPromptPolicy()
    private var task: Task<Void, Never>?
    private var panel: NSPanel?
    private var suggested: MicrophoneApp?

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() { task?.cancel(); task = nil; dismiss() }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        suggested = nil
    }

    private func poll() async {
        guard enabled || monitorsMeeting() else { return }
        let result = await Task.detached(priority: .utility) { Result { try MicrophoneActivity.read() } }.value
        guard !Task.isCancelled, enabled || monitorsMeeting() else { return }
        guard case let .success(processes) = result else {
            dismiss()
            onAvailability("Microphone detection is unavailable. You can still start Acta from Tools.")
            // An unreadable snapshot is not evidence that a meeting ended.
            await onActivity(nil, ProcessInfo.processInfo.systemUptime)
            return
        }
        onAvailability(nil)
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
            .compactMap { app -> MicrophoneApp? in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return MicrophoneApp(pid: app.processIdentifier, bundleID: bundleID, name: app.localizedName ?? bundleID)
            }
        let ownBundle = Bundle.main.bundleIdentifier ?? "work.tapas.Tapas"
        var active: [String: MicrophoneApp] = [:]
        for process in processes {
            if let app = MicrophoneAppAttribution.owner(pid: process.pid, bundleID: process.bundleID, apps: apps,
                ownPID: ProcessInfo.processInfo.processIdentifier, ownBundleID: ownBundle) { active[app.bundleID] = app }
        }
        let now = ProcessInfo.processInfo.systemUptime
        await onActivity(Array(active.values), now)
        guard enabled else { return }
        let allowed = canPrompt()
        let inProgress = actaInProgress()
        if let suggested, active[suggested.bundleID]?.pid != suggested.pid || !allowed || inProgress { dismiss() }
        let foreground = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let ordered = active.keys.sorted { lhs, rhs in
            if lhs == rhs { return false }
            if lhs == foreground { return true }
            if rhs == foreground { return false }
            return lhs < rhs
        }
        if let id = policy.update(activeApps: ordered, now: now, canPrompt: allowed && suggested == nil, actaInProgress: inProgress), let app = active[id] {
            show(app)
        }
    }

    private func show(_ app: MicrophoneApp) {
        suggested = app
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.contentView = NSHostingView(rootView: MeetingPromptView(appName: app.name, ready: isReady(), start: { [weak self] in
            guard let self, let selected = suggested, enabled, canPrompt(), !actaInProgress() else { self?.dismiss(); return }
            dismiss()
            onStart(selected)
        }, dismiss: { [weak self] in self?.dismiss() }))
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 420, y: screen.visibleFrame.minY + 24))
        }
        self.panel = panel
        // A suggestion must not take focus away from the meeting app.
        panel.orderFrontRegardless()
    }
}

struct MeetingPromptView: View {
    let appName: String
    var ready = true
    let start: () -> Void
    let dismiss: () -> Void
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                TapasWordmark(size: 23)
                Text("A conversation worth keeping?").font(.system(size: 20, weight: .bold))
                Text("\(appName) is using your microphone. Acta can keep a transcript on your Mac.")
                    .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    Button(ready ? "Record meeting" : "Set up & record", action: start).buttonStyle(GraficoButtonStyle())
                    Button("Not now", action: dismiss).buttonStyle(.plain)
                }.font(.system(size: 12))
                Text("Start when everyone is ready to be recorded. Saves automatically 30 seconds after this app stops using the microphone.").font(.system(size: 10)).foregroundStyle(Grafico.muted)
            }.plateSurface()
            PintxoWaveform().scaleEffect(0.65).frame(width: 90, height: 70).padding(.trailing, 20)
        }.padding(10).frame(width: 400, height: 300).foregroundStyle(Grafico.ink).preferredColorScheme(.light)
    }
}
