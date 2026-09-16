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
    var meetingDetectionError: String?
    var settings = TapasSettings()
    var entries: [HistoryEntry] = []
    var libraryError: String?
    var tab = "Tools"
    var query = ""
    var selected: HistoryEntry?
    var notice: String?
    var recordingShortcut = false
    var recordingActaShortcut = false
    var shortcutError: String?
    var folderError: String?
    let assistant = AssistantSetupModel()
    var indexMessage: String?
    var selectedTool: String?
    var actaStatus: String?
    var actaRecording = false
    var updates = UpdateModel()
    var preferredWindowSize: NSSize {
        if tab == "Preferences" { return PlateWindowController.preferencesSize }
        return tab == "Tools" && selectedTool == nil ? PlateWindowController.homeSize : PlateWindowController.size
    }
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
    var close: () -> Void = {}
    var cancelShortcutRecording: () -> Void = {}
    var acta: () -> Void = {}
    var recordActaHotkey: () -> Void = {}
    var resetActaHotkey: () -> Void = {}
    var chooseFolder: () -> Void = {}
    var resetFolder: () -> Void = {}
    var checkForUpdates: () -> Void = {}
    var setUpdateChecks: (Bool) -> Void = { _ in }
    var setUpdateDownloads: (Bool) -> Void = { _ in }
    var assistantAction: (String) -> Void = { _ in }
}

struct PlateView: View {
    @Bindable var model: PlateModel
    var actions: PlateActions
    var actaController: ActaController? = nil
    private var homeSelected: Bool { model.tab == "Tools" && model.selectedTool == nil }
    var body: some View {
        VStack(spacing: 0) {
            ReceiptTrim()
            HStack(alignment: .center, spacing: 15) {
                Button { navigate("Tools") } label: { TapasWordmark(size: 23) }
                    .buttonStyle(.plain).accessibilityLabel("Tapas, all tools")
                Spacer()
                Menu {
                    Button("All tools") { navigate("Tools") }
                    Button("Saved words") { navigate("Recent") }
                    Button("Preferences") { navigate("Preferences") }
                    Divider()
                    Button("Setup", action: actions.setup)
                    Button("Check for Updates…", action: actions.checkForUpdates).disabled(!model.updates.canCheck)
                    Divider()
                    Button("Quit Tapas", action: actions.quit)
                } label: { Image(systemName: "ellipsis").font(.system(size: 18)) }
                    .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Tapas menu")
                ClosePlateButton(action: actions.close)
            }.padding(.horizontal, homeSelected ? 18 : 22).padding(.top, 12).padding(.bottom, 8)
            if !homeSelected {
                HStack {
                    Button { navigate("Tools") } label: { Label("All tools", systemImage: "chevron.left") }
                    Spacer()
                    Eyebrow(text: model.selectedTool ?? model.tab)
                }.font(.system(size: 11)).buttonStyle(.plain).padding(.horizontal, 29).padding(.bottom, 16)
            }
            if homeSelected {
                ViewThatFits(in: .vertical) {
                    pageContent.fixedSize(horizontal: false, vertical: true)
                    ScrollView { pageContent }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView { pageContent }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            ReceiptRule().padding(.horizontal, homeSelected ? 18 : 22)
            HStack(spacing: 15) {
                Button("Your files ↗", action: actions.folder)
                Spacer()
                Button(model.tab == "Recent" ? "All tools ↗" : "Saved words ↗") {
                    navigate(model.tab == "Recent" ? "Tools" : "Recent")
                }
            }.font(.system(size: 11)).buttonStyle(.plain).padding(.horizontal, homeSelected ? 18 : 23).padding(.top, 10)
            BrandCredit().padding(.top, 8).padding(.bottom, 15)
        }
        .background { ReceiptPaper().fill(Grafico.card).shadow(color: Grafico.ink.opacity(0.20), radius: 14, x: 4, y: 12) }
        .padding(16).frame(width: model.preferredWindowSize.width, height: model.preferredWindowSize.height)
        .foregroundStyle(Grafico.ink).preferredColorScheme(.light)
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let notice = model.notice { NoticeBox(text: notice) }
            if model.snapshot.phase == .recovery || model.snapshot.phase == .failed {
                ResultView(snapshot: model.snapshot, actions: actions)
                ReceiptRule()
            }
            if homeSelected { tools }
            else if model.tab == "Tools" {
                if model.selectedTool == "Acta", let actaController { ActaView(model: actaController.model, controller: actaController) }
                else { dictado }
            } else if model.tab == "Recent" { recent }
            else { preferences }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, homeSelected ? 18 : 23).padding(.top, 4).padding(.bottom, homeSelected ? 12 : 24)
    }

    private func navigate(_ tab: String) {
        actions.cancelShortcutRecording()
        model.tab = tab
        model.selected = nil
        model.selectedTool = nil
    }

    private var tools: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let status = model.actaStatus {
                HStack { Label(status, systemImage: model.actaRecording ? "record.circle" : "pause.circle"); Spacer(); Button("Return →", action: actions.acta) }
                    .font(.system(size: 11)).foregroundStyle(Grafico.cobalt).buttonStyle(.plain)
            }
            if let error = model.meetingDetectionError { NoticeBox(text: error, error: true) }
            if let error = model.modelError { NoticeBox(text: error, error: true) }
            if model.warming { ProgressView(value: model.progress).tint(Grafico.olive) }
            ReceiptRule()
            receiptTool(acta: false)
            ReceiptRule()
            receiptTool(acta: true)
            Text("More on the menu soon.")
                .font(.system(size: 12, design: .serif)).italic().foregroundStyle(Grafico.muted)
                .frame(maxWidth: .infinity).padding(.vertical, 4)

        }
    }

    private func receiptTool(acta: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(acta ? "02" : "01").font(.system(size: 10, design: .monospaced)).foregroundStyle(Grafico.muted)
                VStack(alignment: .leading, spacing: 3) {
                    Text(acta ? "Acta" : "Dictado").font(.system(size: 24, weight: .semibold)).tracking(-0.7)
                    Text(acta ? "A conversation, to keep." : "One thought, into words.")
                        .font(.system(size: 12, design: .serif)).italic().foregroundStyle(Grafico.muted)
                }
                Spacer()
            }
            if acta {
                Button(action: actions.acta) {
                    HStack { Text(model.actaStatus == nil ? "Open Acta" : "Return to meeting"); Spacer(); Text(model.settings.actaHotkey.label) }
                }.buttonStyle(GraficoButtonStyle(blue: true))
                Text("Recording starts when you choose.").font(.system(size: 10)).foregroundStyle(Grafico.muted)
            } else {
                dictadoButton
            }
        }.padding(.vertical, 2)
    }

    private var dictadoButton: some View {
        Button(action: model.ready && model.microphoneGranted ? actions.talk : actions.setup) {
            HStack {
                Text(model.snapshot.phase == .listening ? "Finish take" : model.snapshot.phase == .finishing ? "Finishing…" : model.ready && model.microphoneGranted ? (model.actaRecording ? "Pause Acta & talk" : "Start a take") : "Finish setup")
                Spacer(); Text(model.settings.hotkey.label)
            }
        }.buttonStyle(GraficoButtonStyle()).disabled(model.snapshot.phase == .finishing || model.snapshot.phase == .starting || model.snapshot.phase == .recovery)
    }

    private var dictado: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("Dictado").font(.system(size: 30, weight: .bold))
            Text("Press. Speak. Press again. Your words return to the app you were using.").font(.system(size: 13)).foregroundStyle(Grafico.muted)
            dictadoButton
            if model.snapshot.phase == .listening { Button("Cancel take", action: actions.cancel).buttonStyle(.plain) }
            if !model.snapshot.committedText.isEmpty {
                Text(model.snapshot.committedText).textSelection(.enabled)
                Button("Copy words") { actions.copy(model.snapshot.committedText) }.buttonStyle(GraficoButtonStyle(secondary: true))
            }
            if !model.accessibilityTrusted || !model.shortcutRunning {
                NoticeBox(text: "Accessibility enables global shortcuts and automatic paste. You can use the buttons and copy your words.")
                Button("Shortcut & paste settings", action: actions.setup).buttonStyle(.plain)
            }
        }
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
            TextField("Find a thought…", text: $model.query).textFieldStyle(.roundedBorder).accessibilityLabel("Search recent transcripts")
            if let error = model.libraryError { NoticeBox(text: error, error: true) }
            let entries = model.entries.filter { model.query.isEmpty || ($0.text + $0.url.lastPathComponent).localizedCaseInsensitiveContains(model.query) }
            if entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.query.isEmpty ? "Room for your first thought." : "No matching thoughts.").font(.system(size: 20, design: .serif)).italic()
                    Text(model.query.isEmpty ? "Acta meetings and Dictado takes with history on appear here." : "Try another word.").font(.system(size: 12)).foregroundStyle(Grafico.muted)
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
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Recording")
            PreferenceToggle("Show live words", detail: "Preview words as you speak. Hover over the recording signal to finish or cancel.", isOn: $model.settings.overlayEnabled)
                .onChange(of: model.settings.overlayEnabled) { _, _ in actions.preferencesChanged() }
            PreferenceToggle("Save Dictado history", detail: "Save a redacted Markdown copy of each take. Applies to your next take; Acta always saves the full transcript.", isOn: $model.settings.historyEnabled)
                .onChange(of: model.settings.historyEnabled) { _, _ in actions.preferencesChanged() }
            PreferenceToggle("Suggest Acta", detail: "Offer to record when another app uses your microphone. Recording starts only when you choose Start Acta. No calendar connection needed.", isOn: $model.settings.meetingPromptsEnabled)
                .onChange(of: model.settings.meetingPromptsEnabled) { _, _ in actions.preferencesChanged() }
            if let error = model.meetingDetectionError { NoticeBox(text: error, error: true) }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Shortcuts")
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dictado").fontWeight(.medium)
                        Menu(model.settings.hotkey.label) {
                            Button("Control–Option") { actions.setHotkey(.standard) }
                            Button("Right Command") { actions.setHotkey(.rightCommand) }
                            Button("Record a shortcut…", action: actions.recordHotkey)
                        }.menuStyle(.borderlessButton).fixedSize()
                            .modifier(GraficoMenuSurface())
                            .accessibilityLabel("Dictado shortcut")
                            .disabled(model.snapshot.phase.isActive)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Acta").fontWeight(.medium)
                        Menu(model.settings.actaHotkey.label) {
                            Button("Control–Shift–M", action: actions.resetActaHotkey)
                            Button("Record a shortcut…", action: actions.recordActaHotkey)
                        }.menuStyle(.borderlessButton).fixedSize()
                            .modifier(GraficoMenuSurface())
                            .accessibilityLabel("Acta shortcut")
                            .disabled(model.snapshot.phase.isActive)
                    }
                }.padding(.bottom, 3)
                Text("Acta’s shortcut opens the tool without recording. Use a key with at least two modifiers.")
                    .font(.system(size: 11)).foregroundStyle(Grafico.muted)
                if model.recordingShortcut || model.recordingActaShortcut { NoticeBox(text: "Press your new shortcut, then release. Escape keeps the current one.") }
                if let error = model.shortcutError { NoticeBox(text: error, error: true) }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Transcript folder")
                Text(model.settings.transcriptDirectory.path).font(.system(size: 11)).foregroundStyle(Grafico.muted).textSelection(.enabled)
                Text("New recordings go into dictado and acta subfolders. Existing files and recordings in progress keep their original location.")
                    .font(.system(size: 11)).foregroundStyle(Grafico.muted)
                HStack(spacing: 8) {
                    Button("Choose…", action: actions.chooseFolder)
                    Button("Open", action: actions.folder)
                    Button("Use default", action: actions.resetFolder)
                }.padding(.bottom, 3)
                if let error = model.folderError { NoticeBox(text: error, error: true) }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Use with your AI assistant")
                Text("Find and cite recordings in your transcript folder. Older folder locations remain discoverable.")
                    .font(.system(size: 11)).foregroundStyle(Grafico.muted)
                AssistantSetupView(model: model.assistant, onAction: actions.assistantAction)
                Button("Open templates") { actions.assistantAction("templates") }
                Text("Make meeting notes your own. Edit or add Markdown templates; your assistant reads them when you ask. Existing files are preserved.")
                    .font(.system(size: 11)).foregroundStyle(Grafico.muted)
                HStack {
                    Button("Remove") { actions.assistantAction("remove") }
                        .disabled(!["Installed", "Update available"].contains(model.assistant.status))
                    Button("Copy setup command") { actions.assistantAction("copy") }
                }
                Text("Remote assistants cannot automatically read this Mac. Cursor reuses compatible personal installations; removing a shared skill affects those assistants too.")
                    .font(.system(size: 11)).foregroundStyle(Grafico.muted)
                Button("Rebuild recording indexes") { actions.assistantAction("rebuild") }
                if let message = model.indexMessage { Text(message).font(.system(size: 11)).textSelection(.enabled) }
            }
            Divider()
            if model.updates.available {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Updates")
                    PreferenceToggle("Check automatically", isOn: Binding(get: { model.updates.automaticallyChecks }, set: { actions.setUpdateChecks($0) }))
                    PreferenceToggle("Download automatically", isOn: Binding(get: { model.updates.automaticallyDownloads }, set: { actions.setUpdateDownloads($0) }))
                        .disabled(!model.updates.automaticallyChecks)
                    Text("Install updates in the app. Recording and unsaved words take priority over restarting.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
                    if model.updates.waitingForRecording { NoticeBox(text: "An update is ready. Finish or recover your recording before Tapas restarts.") }
                    Button("Check for Updates…", action: actions.checkForUpdates).disabled(!model.updates.canCheck)
                        .padding(.bottom, 3)
                }
                Divider()
            }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Permissions")
                Text("Shortcuts & paste access: \(model.accessibilityTrusted ? "allowed" : "off")").fontWeight(.medium)
                Text("Accessibility enables global shortcuts and Dictado’s paste. Acta audio has its own permission step.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
                Button("Microphone & Accessibility…", action: actions.setup).padding(.bottom, 3)
            }
            Text("25 European languages · automatic\nVoice processing stays on this Mac.").font(.system(size: 11)).lineSpacing(4).foregroundStyle(Grafico.muted)
        }.buttonStyle(GraficoButtonStyle(secondary: true, compact: true))
            .tint(Grafico.olive).font(.system(size: 13))
    }

}

private struct PreferenceToggle: View {
    var title: String
    var detail: String
    @Binding var isOn: Bool

    init(_ title: String, detail: String = "", isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        self._isOn = isOn
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle(title, isOn: $isOn)
                .labelsHidden().toggleStyle(.switch).fixedSize()
                .accessibilityHint(detail)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium))
                if !detail.isEmpty {
                    Text(detail).font(.system(size: 11)).foregroundStyle(Grafico.muted)
                }
            }.padding(.top, 3).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
        }
    }
}

struct ResultView: View {
    var snapshot: OverlaySnapshot
    var actions: PlateActions
    var actaController: ActaController? = nil
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
