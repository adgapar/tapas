import AppKit
import SwiftUI
import TapasCore

@MainActor @Observable
final class PlateModel {
    var snapshot = OverlaySnapshot()
    var ready = false
    var microphoneGranted = false
    var accessibilityTrusted = false
    var shortcutRunning = false
    var warming = false
    var progress: Double = 0
    var modelError: String?
    var settings = TapasSettings()
    var entries: [HistoryEntry] = []
    var libraryError: String?
    var tab = "Tools"
    var query = ""
    var selected: HistoryEntry?
    var notice: String?
    var recordingShortcut = false
}

struct PlateActions {
    var talk: () -> Void
    var setup: () -> Void
    var setHotkey: (Hotkey) -> Void
    var recordHotkey: () -> Void
    var preferencesChanged: () -> Void
    var folder: () -> Void
    var copy: (String) -> Void
    var export: (String) -> Void
    var dismiss: () -> Void
    var retryPaste: () -> Void
    var retrySave: () -> Void
    var cancel: () -> Void
    var quit: () -> Void
}

struct PlateView: View {
    @Bindable var model: PlateModel
    var actions: PlateActions
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Your plate.").font(.system(size: 28, weight: .bold)).tracking(-1)
                    Text(Grafico.tagline).font(.system(size: 12, design: .serif)).italic().foregroundStyle(Grafico.muted)
                }
                Spacer()
                PintxoMark(phase: model.snapshot.phase).frame(width: 52, height: 68)
            }.padding(24)
            HStack(spacing: 0) {
                ForEach(["Tools", "Recent", "Preferences"], id: \.self) { tab in
                    Button { model.tab = tab; model.selected = nil } label: {
                        VStack(spacing: 10) {
                            Text(tab).font(.system(size: 12, weight: model.tab == tab ? .semibold : .regular))
                            Rectangle().fill(model.tab == tab ? Grafico.ink : .clear).frame(height: 2)
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(.plain).accessibilityAddTraits(model.tab == tab ? .isSelected : [])
                }
            }.padding(.horizontal, 24)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let notice = model.notice { NoticeBox(text: notice) }
                    if model.snapshot.phase == .recovery || model.snapshot.phase == .failed {
                        ResultView(snapshot: model.snapshot, actions: actions)
                    }
                    if model.tab == "Tools" { tools }
                    else if model.tab == "Recent" { recent }
                    else { preferences }
                }.padding(24)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Button("Your files ↗", action: actions.folder)
                Spacer()
                Menu {
                    Button("Setup…", action: actions.setup)
                    Button("Powered by Desert Ant Labs") { NSWorkspace.shared.open(URL(string: "https://desertant.com")!) }
                    Divider()
                    Button("Quit Tapas", action: actions.quit)
                } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("More options") }.menuStyle(.borderlessButton).fixedSize()
            }.font(.system(size: 11)).buttonStyle(.plain).padding(18).background(Grafico.paper)
        }
        .frame(width: 410, height: 620).foregroundStyle(Grafico.ink).background(Grafico.card).preferredColorScheme(.light)
    }

    private var tools: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { ToolGlyph(symbol: "waveform"); Spacer(); Eyebrow(text: model.ready && model.microphoneGranted ? "Ready to serve" : "A little preparation") }
            Text("Dictado").font(.system(size: 30, weight: .bold)).tracking(-1)
            Text("A thought, a message, a whole paragraph.\nSay it where you want to write it.").font(.system(size: 13)).lineSpacing(4)
            if model.warming {
                ProgressView(value: model.progress).tint(Grafico.olive)
                Text(model.progress >= 0.9 ? "Preparing your voice models…" : "Downloading voice models…").font(.system(size: 11))
            }
            if let error = model.modelError { NoticeBox(text: error, error: true) }
            Button(action: model.ready && model.microphoneGranted ? actions.talk : actions.setup) {
                HStack {
                    Text(model.snapshot.phase == .listening ? "Finish take" : model.snapshot.phase == .finishing ? "Finishing…" : model.ready && model.microphoneGranted ? "Start a take" : "Finish setup")
                    Spacer(); Text(model.settings.hotkey.label)
                }
            }.buttonStyle(GraficoButtonStyle()).disabled(model.snapshot.phase == .finishing || model.snapshot.phase == .starting || model.snapshot.phase == .recovery)
            if model.snapshot.phase == .listening { Button("Cancel take", action: actions.cancel).buttonStyle(.plain) }
            if !model.accessibilityTrusted || !model.shortcutRunning {
                Text(model.accessibilityTrusted ? "Global shortcut unavailable. Reopen Tapas or use Start a take." : "Paste access is off. Start here and copy your words after finishing.")
                    .font(.system(size: 11)).foregroundStyle(Grafico.muted)
                Button("Shortcut & paste settings", action: actions.setup).buttonStyle(.plain).font(.system(size: 11))
            }
            Divider()
            future("Acta", "Be there. Keep the conversation.", "NEXT", "text.bubble", Grafico.cobalt)
            future("Captura", "A moment, with a little context.", "LATER", "viewfinder", Grafico.paprika)
            future("Consulta", "The file you were thinking of.", "LATER", "magnifyingglass", Grafico.olive)
        }
    }

    private func future(_ title: String, _ subtitle: String, _ badge: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            ToolGlyph(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(Grafico.muted)
            }
            Spacer(minLength: 0)
            Text(badge).font(.system(size: 8, weight: .medium, design: .monospaced)).padding(5).background(Grafico.paper, in: RoundedRectangle(cornerRadius: 3))
        }.accessibilityElement(children: .combine)
    }

    @ViewBuilder private var recent: some View {
        if let entry = model.selected {
            Button("← Recent files") { model.selected = nil }.buttonStyle(.plain)
            Text(entry.title).font(.system(size: 20, weight: .semibold))
            Text(entry.url.lastPathComponent).font(.system(size: 10, design: .monospaced)).foregroundStyle(Grafico.muted)
            Text(entry.text).font(.system(size: 14)).lineSpacing(5).textSelection(.enabled)
            HStack {
                Button("Copy text") { actions.copy(entry.text) }.buttonStyle(GraficoButtonStyle())
                Button("Open file ↗") { NSWorkspace.shared.open(entry.url) }.buttonStyle(GraficoButtonStyle(secondary: true))
            }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }.buttonStyle(.plain)
        } else {
            TextField("Find a thought…", text: $model.query).textFieldStyle(.roundedBorder).accessibilityLabel("Search recent dictations")
            if let error = model.libraryError { NoticeBox(text: error, error: true) }
            let entries = model.entries.filter { model.query.isEmpty || ($0.text + $0.url.lastPathComponent).localizedCaseInsensitiveContains(model.query) }
            if entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.query.isEmpty ? "Room for your first thought." : "No matching thoughts.").font(.system(size: 20, design: .serif)).italic()
                    Text(model.query.isEmpty ? "Finished takes appear here when history is on." : "Try another word.").font(.system(size: 12)).foregroundStyle(Grafico.muted)
                }.padding(.vertical, 30)
            }
            ForEach(entries) { entry in
                Button { model.selected = entry } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.title).font(.system(size: 13, weight: .medium)).lineLimit(2)
                            Text(entry.date, format: .dateTime.month().day().hour().minute()).font(.system(size: 10)).foregroundStyle(Grafico.muted)
                        }
                        Spacer(); Image(systemName: "arrow.up.right")
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                }.buttonStyle(.plain)
                Divider()
            }
        }
    }

    private var preferences: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Shortcut").font(.system(size: 13, weight: .medium)); Spacer()
                Menu(model.settings.hotkey.label) {
                    Button("Control–Option") { actions.setHotkey(.standard) }
                    Button("Right Command") { actions.setHotkey(.rightCommand) }
                    Button("Record a shortcut…", action: actions.recordHotkey)
                }.fixedSize().disabled(model.snapshot.phase.isActive)
            }
            if model.recordingShortcut { NoticeBox(text: "Press your new shortcut. Escape keeps the current one.") }
            Toggle("Show live words", isOn: $model.settings.overlayEnabled).onChange(of: model.settings.overlayEnabled) { _, _ in actions.preferencesChanged() }
            Text("Preview your words as you speak. Recording status and controls always stay visible.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            Toggle("Save a history", isOn: $model.settings.historyEnabled).onChange(of: model.settings.historyEnabled) { _, _ in actions.preferencesChanged() }
            Text("Keep a redacted Markdown copy after each take. Changing this applies to your next take.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            Divider()
            HStack { Text("Paste access"); Spacer(); Text(model.accessibilityTrusted ? "Allowed" : "Off").foregroundStyle(Grafico.muted) }
            Button("Microphone & Accessibility…", action: actions.setup).buttonStyle(.plain)
            Text("25 European languages · automatic\nVoice processing stays on this Mac.").font(.system(size: 11)).lineSpacing(4).foregroundStyle(Grafico.muted)
            Button("Powered by Desert Ant Labs ↗") { NSWorkspace.shared.open(URL(string: "https://desertant.com")!) }.buttonStyle(.plain).font(.system(size: 11))
        }.toggleStyle(.switch).tint(Grafico.olive).font(.system(size: 13))
    }
}

struct ResultView: View {
    var snapshot: OverlaySnapshot
    var actions: PlateActions
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NoticeBox(text: snapshot.message ?? "Your words are kept.", error: true)
            if !snapshot.committedText.isEmpty {
                Text(snapshot.committedText).font(.system(size: 14)).lineLimit(8).textSelection(.enabled)
                HStack {
                    Button("Copy words") { actions.copy(snapshot.committedText) }.buttonStyle(GraficoButtonStyle())
                    Button("Export…") { actions.export(snapshot.committedText) }.buttonStyle(GraficoButtonStyle(secondary: true))
                }
            }
            HStack {
                if snapshot.pasteFailed { Button("Retry paste", action: actions.retryPaste) }
                if snapshot.saveFailed { Button("Retry save", action: actions.retrySave) }
                Button("Dismiss", action: actions.dismiss)
            }.buttonStyle(.plain).font(.system(size: 12))
        }

    }
}
