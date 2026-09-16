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
    var selectedTool: String?
    var actaStatus: String?
    var actaRecording = false
    var updates = UpdateModel()
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
}

struct PlateView: View {
    @Bindable var model: PlateModel
    var actions: PlateActions
    var actaController: ActaController? = nil
    private var homeSelected: Bool { model.tab == "Tools" && model.selectedTool == nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    TapasWordmark()
                    Text(Grafico.tagline).font(.system(size: 11)).foregroundStyle(Grafico.muted).padding(.leading, 41)
                }.floatingLabel()
                Spacer()
                ClosePlateButton(action: actions.close)
            }
            HStack(spacing: 3) {
                ForEach(["Tools", "Recent", "Preferences"], id: \.self) { tab in
                    Button { actions.cancelShortcutRecording(); model.tab = tab; model.selected = nil } label: {
                        Text(tab).font(.system(size: 12, weight: .medium)).padding(.horizontal, 18).padding(.vertical, 9)
                            .foregroundStyle(model.tab == tab ? Grafico.card : Grafico.ink)
                            .background(model.tab == tab ? Grafico.ink : .clear, in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain).accessibilityAddTraits(model.tab == tab ? .isSelected : [])
                }
            }.padding(4).background(Grafico.card, in: RoundedRectangle(cornerRadius: 9))
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    if let notice = model.notice { NoticeBox(text: notice) }
                    if model.snapshot.phase == .recovery || model.snapshot.phase == .failed {
                        ResultView(snapshot: model.snapshot, actions: actions).plateSurface()
                    }
                    if homeSelected { tools }
                    else {
                        VStack(alignment: .leading, spacing: 17) {
                            if model.tab == "Tools" {
                                Button { model.selectedTool = nil } label: { Label("All tools", systemImage: "chevron.left") }.buttonStyle(.plain)
                                if model.selectedTool == "Acta", let actaController { ActaView(model: actaController.model, controller: actaController) }
                                else { dictado }
                            } else if model.tab == "Recent" { recent }
                            else { preferences }
                        }.frame(maxWidth: .infinity, alignment: .leading).plateSurface()
                    }
                }.padding(.trailing, 5).padding(.bottom, 7)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 18) {
                Button("Your files ↗", action: actions.folder)
                Button("Setup", action: actions.setup)
                Spacer()
                Text("Local by nature.").foregroundStyle(Grafico.muted)
                Menu {
                    Button("Check for Updates…", action: actions.checkForUpdates).disabled(!model.updates.canCheck)
                    Divider()
                    Button("Quit Tapas", action: actions.quit)
                } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("More options") }.menuStyle(.borderlessButton).fixedSize()
            }.font(.system(size: 11)).buttonStyle(.plain).floatingLabel()
        }.padding(24).frame(width: 710, height: 770).foregroundStyle(Grafico.ink).preferredColorScheme(.light)
    }

    private var tools: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "A little room for your day")
                    Text("What’s on your plate?").font(.system(size: 23, weight: .semibold)).tracking(-0.5)
                }
                Spacer()
                Label("On this Mac", systemImage: "circle.fill").font(.system(size: 9)).foregroundStyle(Grafico.olive)
            }.floatingLabel()
            if let status = model.actaStatus {
                HStack { Text(status).font(.system(size: 12)); Spacer(); Button("Return →", action: actions.acta).buttonStyle(.plain) }
                    .padding(12).background(Grafico.card, in: RoundedRectangle(cornerRadius: 9))
            }
            if let error = model.meetingDetectionError { NoticeBox(text: error, error: true) }
            if let error = model.modelError { NoticeBox(text: error, error: true) }
            if model.warming { ProgressView(value: model.progress).tint(Grafico.olive) }
            HStack(alignment: .top, spacing: 18) {
                toolCard(acta: false)
                toolCard(acta: true)
            }
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Eyebrow(text: model.entries.isEmpty ? "Your words, within reach" : "Last on your plate")
                    Spacer()
                    Button("All recent →") { model.tab = "Recent"; model.selected = nil }.buttonStyle(.plain).font(.system(size: 11))
                }
                if let entry = model.entries.first {
                    Button { model.tab = "Recent"; model.selected = entry } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text").font(.system(size: 24)).foregroundStyle(Grafico.olive)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                Text(entry.date, format: .dateTime.month().day().hour().minute()).font(.system(size: 10)).foregroundStyle(Grafico.muted)
                            }
                            Spacer(); Image(systemName: "arrow.up.right")
                        }
                    }.buttonStyle(.plain)
                } else { Text("Your saved takes and meetings appear here. Start with a thought.").font(.system(size: 11)).foregroundStyle(Grafico.muted) }
            }.plateSurface(Grafico.paper)
        }
    }

    private func toolCard(acta: Bool) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Eyebrow(text: acta ? "A conversation, kept" : "A thought, put into words")
                Spacer(minLength: 4)
                Text(acta ? (model.actaRecording ? "Recording" : actaController?.model.ready == true && actaController?.model.microphoneGranted == true && actaController?.model.appAudioGranted == true ? "Ready" : "Setup") : model.ready && model.microphoneGranted ? "Ready" : "Setup")
                    .font(.system(size: 9)).foregroundStyle(Grafico.muted)
            }.frame(height: 25)
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill((acta ? Grafico.cobalt : Grafico.saffron).opacity(0.10))
                if acta {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Be there.").font(.system(size: 16, design: .serif)).italic()
                        Text("Keep the conversation.").font(.system(size: 13, design: .serif)).italic().foregroundStyle(Grafico.card)
                            .padding(8).background(Grafico.cobalt, in: RoundedRectangle(cornerRadius: 7)).padding(.leading, 20)
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform").font(.system(size: 34)).foregroundStyle(Grafico.olive)
                        Text("hello, idea.").font(.system(size: 18, design: .serif)).italic()
                    }
                }
            }.frame(height: 84)
            Text(acta ? "Acta" : "Dictado").font(.system(size: 27, weight: .bold)).tracking(-0.7)
            Text(acta ? "Your voice and the meeting audio.\nOne transcript to come back to." : "A message. A whole paragraph.\nSay it where you want to write it.")
                .font(.system(size: 12)).foregroundStyle(Grafico.muted).lineSpacing(5).frame(height: 44, alignment: .topLeading)
            if acta {
                Button(action: actions.acta) { HStack { Text(model.actaStatus == nil ? "Open Acta" : "Return to meeting"); Spacer(); Text(model.settings.actaHotkey.label) } }
                    .buttonStyle(GraficoButtonStyle(blue: true))
                Text("Recording starts when you choose.").font(.system(size: 10)).foregroundStyle(Grafico.muted)
            } else {
                dictadoButton
                Button("Open Dictado →") { model.selectedTool = "Dictado" }.buttonStyle(.plain).font(.system(size: 10))
            }
        }.frame(maxWidth: .infinity).plateSurface()
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
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Dictado shortcut").font(.system(size: 13, weight: .medium)); Spacer()
                Menu(model.settings.hotkey.label) {
                    Button("Control–Option") { actions.setHotkey(.standard) }
                    Button("Right Command") { actions.setHotkey(.rightCommand) }
                    Button("Record a shortcut…", action: actions.recordHotkey)
                }.fixedSize().disabled(model.snapshot.phase.isActive)
            }
            HStack {
                Text("Acta shortcut").font(.system(size: 13, weight: .medium)); Spacer()
                Menu(model.settings.actaHotkey.label) {
                    Button("Control–Shift–M", action: actions.resetActaHotkey)
                    Button("Record a shortcut…", action: actions.recordActaHotkey)
                }.fixedSize().disabled(model.snapshot.phase.isActive)
            }
            Text("Opens Acta without starting a recording. Use a key with at least two modifiers.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            if model.recordingShortcut || model.recordingActaShortcut { NoticeBox(text: "Press your new shortcut, then release. Escape keeps the current one.") }
            if let error = model.shortcutError { NoticeBox(text: error, error: true) }
            Divider()
            Text("Transcript folder").font(.system(size: 13, weight: .medium))
            Text(model.settings.transcriptDirectory.path).font(.system(size: 11)).foregroundStyle(Grafico.muted).textSelection(.enabled)
            HStack {
                Button("Choose…", action: actions.chooseFolder)
                Button("Open", action: actions.folder)
                Button("Use default", action: actions.resetFolder)
            }
            Text("New recordings go into dictado and acta subfolders. Existing files and recordings in progress keep their original location.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            if let error = model.folderError { NoticeBox(text: error, error: true) }
            Divider()
            Toggle("Show live words", isOn: $model.settings.overlayEnabled).onChange(of: model.settings.overlayEnabled) { _, _ in actions.preferencesChanged() }
            Text("Preview your words as you speak. The recording signal stays visible; hover to finish or cancel.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            Toggle("Save Dictado history", isOn: $model.settings.historyEnabled).onChange(of: model.settings.historyEnabled) { _, _ in actions.preferencesChanged() }
            Text("Keep a redacted Markdown copy after each take. Changing this applies to your next take. Acta always saves its full meeting transcript.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            Divider()
            Toggle("Suggest Acta when the microphone is in use", isOn: $model.settings.meetingPromptsEnabled)
                .onChange(of: model.settings.meetingPromptsEnabled) { _, _ in actions.preferencesChanged() }
            Text("Offer to record when another app uses your microphone. Nothing is recorded until you choose Start Acta. No calendar connection needed.")
                .font(.system(size: 11)).foregroundStyle(Grafico.muted)
            if let error = model.meetingDetectionError { NoticeBox(text: error, error: true) }
            Divider()
            if model.updates.available {
                Text("Updates").font(.system(size: 15, weight: .semibold))
                Toggle("Automatically check for updates", isOn: Binding(get: { model.updates.automaticallyChecks }, set: { actions.setUpdateChecks($0) }))
                Toggle("Download updates automatically", isOn: Binding(get: { model.updates.automaticallyDownloads }, set: { actions.setUpdateDownloads($0) }))
                    .disabled(!model.updates.automaticallyChecks)
                Text("Install updates in the app. Recording and unsaved words take priority over restarting.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
                if model.updates.waitingForRecording { NoticeBox(text: "An update is ready. Finish or recover your recording before Tapas restarts.") }
                Button("Check for Updates…", action: actions.checkForUpdates).disabled(!model.updates.canCheck)
                Divider()
            }
            HStack { Text("Shortcuts & paste access"); Spacer(); Text(model.accessibilityTrusted ? "Allowed" : "Off").foregroundStyle(Grafico.muted) }
            Text("Accessibility enables global shortcuts and Dictado’s paste. Acta audio has its own permission step.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            Button("Microphone & Accessibility…", action: actions.setup).buttonStyle(.plain)
            Text("25 European languages · automatic\nVoice processing stays on this Mac.").font(.system(size: 11)).lineSpacing(4).foregroundStyle(Grafico.muted)
            Button("Powered by Desert Ant Labs ↗") { NSWorkspace.shared.open(URL(string: "https://desertant.com")!) }.buttonStyle(.plain).font(.system(size: 11))
        }.toggleStyle(.switch).tint(Grafico.olive).font(.system(size: 13))
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
