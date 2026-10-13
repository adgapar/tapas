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
    var entries: [HistoryEntry] = [] {
        didSet { kept = entries.map(KeptItem.init) }
    }
    private(set) var kept: [KeptItem] = []
    var filter = "all"
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
        selectedTool == "Acta" ? PlateWindowController.size : PlateWindowController.homeSize
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
    var openAccessibility: () -> Void = {}
}

/// The home card, opened from the pintxo in the menu bar (Sobremesa).
/// Front: what you kept. Back: house rules. Acta opens in the same card.
struct PlateView: View {
    @Bindable var model: PlateModel
    var actions: PlateActions
    var actaController: ActaController? = nil

    private var cardSize: NSSize {
        NSSize(width: model.preferredWindowSize.width - 20, height: model.preferredWindowSize.height - 20)
    }

    var body: some View {
        Group {
            if model.selectedTool == "Acta", let actaController {
                face { actaPage(actaController) }
            } else {
                FlipCard(flipped: model.tab == "Preferences") {
                    face { front }
                } back: {
                    face { back }
                }
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .padding(.leading, 6).padding(.top, 6).padding(.trailing, 14).padding(.bottom, 14)
        .frame(width: model.preferredWindowSize.width, height: model.preferredWindowSize.height, alignment: .topLeading)
        .foregroundStyle(Sobremesa.ink)
        .preferredColorScheme(.light)
    }

    private func face<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: cardSize.width, height: cardSize.height, alignment: .top)
            .clipShape(CutShape(tight: 6, round: 22, corner: .topTrailing))
            .printed(CutShape(tight: 6, round: 22, corner: .topTrailing))
    }

    private func navigate(_ tab: String) {
        actions.cancelShortcutRecording()
        model.tab = tab
        model.selected = nil
        model.selectedTool = nil
    }

    // MARK: Front

    private var front: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 10) { status }.padding(.horizontal, 24)
            if let entry = model.selected { detail(KeptItem(entry)) } else { list }
            footer(flip: "House rules", to: "Preferences")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("tapas").font(Sobremesa.display(26, weight: 620)).padding(.trailing, 4)
            Spacer(minLength: 0)
            Button(action: model.ready && model.microphoneGranted ? actions.talk : actions.setup) {
                HStack(spacing: 6) { Text(dictadoTitle); Text(model.settings.hotkey.label).foregroundStyle(Sobremesa.ink.opacity(0.6)) }
            }
            .buttonStyle(.printed(.primary, small: true))
            .disabled(model.snapshot.phase == .finishing || model.snapshot.phase == .starting || model.snapshot.phase == .recovery)
            Button(action: actions.acta) {
                HStack(spacing: 6) { Text(model.actaStatus == nil ? "Acta" : "Return to Acta"); Text(model.settings.actaHotkey.label).foregroundStyle(Sobremesa.ink.opacity(0.6)) }
            }.buttonStyle(.printed(.secondary, small: true))
            Menu {
                Button("House rules") { navigate("Preferences") }
                Button("Setup…", action: actions.setup)
                Button("Check for Updates…", action: actions.checkForUpdates).disabled(!model.updates.canCheck)
                Divider()
                Button("Quit tapas", action: actions.quit)
            } label: { Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold)).foregroundStyle(Sobremesa.ink).frame(width: 26, height: 26) }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize().accessibilityLabel("tapas menu")
            Button(action: actions.close) { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).frame(width: 26, height: 26) }
                .buttonStyle(.plain).accessibilityLabel("Close tapas")
        }
        .padding(.leading, 24).padding(.trailing, 16).padding(.top, 18).padding(.bottom, 10)
    }

    private var dictadoTitle: String {
        if model.snapshot.phase == .listening { return "Finish take" }
        if model.snapshot.phase == .finishing { return "Finishing…" }
        if !(model.ready && model.microphoneGranted) { return "Finish setup" }
        return model.actaRecording ? "Pause Acta & write" : "Dictado"
    }

    @ViewBuilder private var status: some View {
        if let notice = model.notice { Notice(text: notice) }
        if let status = model.actaStatus {
            HStack {
                Text(status).font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Button("Return", action: actions.acta).buttonStyle(.printed(.quiet, small: true))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .printed(CutShape(tight: 3, round: 12), fill: Sobremesa.cobaltTint, offset: CGSize(width: 2, height: 3))
        }
        if let error = model.modelError { Notice(text: error, error: true) }
        if model.warming {
            HStack(spacing: 10) {
                SkewerPintxo(form: .resting, progress: model.progress).frame(width: 30, height: 30)
                Text("Preparing the speech model · \(Int(model.progress * 100))%").font(.system(size: 12.5, weight: .semibold))
            }
        }
        if model.snapshot.phase == .recovery || model.snapshot.phase == .failed {
            ResultView(snapshot: model.snapshot, actions: actions)
        }
    }

    private var filtered: [KeptItem] {
        model.kept.filter { item in
            (model.filter == "all" || (model.filter == "meetings") == item.isMeeting)
                && (model.query.isEmpty || (item.entry.text + item.entry.url.lastPathComponent).localizedCaseInsensitiveContains(model.query))
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("", text: $model.query, prompt: Text("Find something that was said…").foregroundStyle(Sobremesa.muted))
                .textFieldStyle(.plain).font(Sobremesa.display(22))
                .accessibilityLabel("Search what you kept")
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(Sobremesa.ink).frame(height: 2) }
            HStack(spacing: 16) {
                ForEach([("all", "Everything"), ("meetings", "Meetings"), ("takes", "Takes")], id: \.0) { value, title in
                    Button(title) { model.filter = value }
                        .buttonStyle(.plain).font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(model.filter == value ? Sobremesa.ink : Sobremesa.muted)
                        .padding(.vertical, 3)
                        .overlay(alignment: .bottom) { Rectangle().fill(model.filter == value ? Sobremesa.saffron : .clear).frame(height: 3) }
                        .accessibilityAddTraits(model.filter == value ? .isSelected : [])
                }
                Spacer()
                legend(Sobremesa.cobalt, "you"); legend(Sobremesa.paprika, "others")
            }
            if let error = model.libraryError { Notice(text: error, error: true) }
            let items = filtered
            if items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.query.isEmpty ? "Vale. Room for your first thought." : "Nothing matches that yet.")
                        .font(Sobremesa.display(24, weight: 500))
                    Text(model.query.isEmpty ? "Press \(model.settings.hotkey.label) to write, or open Acta when a call starts. Takes appear here when keeping a copy is on." : "Try another word.")
                        .font(.system(size: 13)).foregroundStyle(Sobremesa.muted).fixedSize(horizontal: false, vertical: true)
                }.padding(.vertical, 28)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index == 0 || !Calendar.current.isDate(items[index - 1].entry.date, inSameDayAs: item.entry.date) {
                                HStack {
                                    GroupLabel(text: dayName(item.entry.date))
                                    Spacer()
                                    GroupLabel(text: item.entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                }.padding(.top, 14).padding(.bottom, 4)
                            }
                            KeptRow(item: item) { model.selected = item.entry }
                        }
                    }.padding(.bottom, 8)
                }.scrollIndicators(.never)
            }
        }
        .padding(.horizontal, 24).padding(.top, 6)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 6, height: 11)
            Text(title).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Sobremesa.muted)
        }
    }

    private func dayName(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private func detail(_ item: KeptItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("← What you kept") { model.selected = nil }.buttonStyle(.printed(.quiet, small: true))
            Text(item.firstWords).font(Sobremesa.display(22, weight: 500)).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("\(item.entry.date.formatted(.dateTime.day().month().hour().minute())) · \(item.meta)")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Sobremesa.muted)
                Spacer()
                RecordingShapeView(columns: item.shape())
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if item.isMeeting {
                        ForEach(Array(item.turns.enumerated()), id: \.offset) { _, turn in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(ActaDocument.timestamp(turn.start)) · \(turn.mine ? "You" : "Others")")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(turn.mine ? Sobremesa.cobalt : Sobremesa.paprika)
                                Text(turn.text).font(Sobremesa.display(15))
                            }
                        }
                    } else {
                        Text(item.entry.text).font(Sobremesa.display(16)).lineSpacing(4)
                    }
                }.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 14) {
                Button("Copy text") { actions.copy(item.entry.text) }.buttonStyle(.printed(.primary, small: true))
                Button("Open file ↗") { NSWorkspace.shared.open(item.entry.url) }.buttonStyle(.printed(.secondary, small: true))
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.entry.url]) }.buttonStyle(.printed(.quiet, small: true))
            }.padding(.bottom, 4)
        }
        .padding(.horizontal, 24).padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func footer(flip title: String, to tab: String) -> some View {
        HStack {
            Button("Open folder ↗", action: actions.folder).buttonStyle(.printed(.quiet, small: true))
            Spacer()
            Button { navigate(tab) } label: {
                HStack(spacing: 6) { Text(title); Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 11, weight: .bold)) }
            }.buttonStyle(.printed(.secondary, small: true))
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 18)
        .overlay(alignment: .top) { Rectangle().fill(Sobremesa.ink.opacity(0.14)).frame(height: 1) }
    }

    // MARK: Back

    private var back: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("House rules").font(Sobremesa.display(32, weight: 600))
                    Text("Tap a switch, an underlined word, or a shortcut to change it.")
                        .font(.system(size: 13)).foregroundStyle(Sobremesa.muted)
                }
                Spacer()
                Button(action: actions.close) { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).frame(width: 26, height: 26) }
                    .buttonStyle(.plain).accessibilityLabel("Close tapas")
            }
            .padding(.leading, 24).padding(.trailing, 16).padding(.top, 20)
            ScrollView {
                HouseRulesView(model: model, actions: actions).padding(.horizontal, 24).padding(.bottom, 16)
            }.scrollIndicators(.never)
            footer(flip: "What you kept", to: "Recent")
        }
    }

    // MARK: Acta

    private func actaPage(_ controller: ActaController) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("← What you kept") { navigate("Recent") }.buttonStyle(.printed(.quiet, small: true))
                Spacer()
                Button(action: actions.close) { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).frame(width: 26, height: 26) }
                    .buttonStyle(.plain).accessibilityLabel("Close tapas")
            }.padding(.leading, 24).padding(.trailing, 16).padding(.top, 18)
            ScrollView {
                ActaView(model: controller.model, controller: controller).padding(.horizontal, 24).padding(.vertical, 12)
            }.scrollIndicators(.never)
        }
    }
}

/// One recording: time, first words, what it was, and its shape.
struct KeptRow: View {
    var item: KeptItem
    var open: () -> Void
    // Explicit storage builds with Command Line Tools SDKs that omit the SwiftUI macro plugin.
    private var hoveringState = SwiftUI.State<Bool>(initialValue: false)
    private var hovering: Bool {
        get { hoveringState.wrappedValue }
        nonmutating set { hoveringState.wrappedValue = newValue }
    }
    var body: some View {
        Button(action: open) {
            HStack(alignment: .center, spacing: 12) {
                Text(item.entry.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 12, weight: .semibold)).monospacedDigit().foregroundStyle(Sobremesa.muted)
                    .frame(width: 42, alignment: .leading).frame(maxHeight: .infinity, alignment: .top).padding(.top, 3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.firstWords).font(Sobremesa.display(17)).lineLimit(2).multilineTextAlignment(.leading)
                    Text(item.meta).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Sobremesa.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
                RecordingShapeView(columns: item.shape())
            }
            .padding(.vertical, 11).padding(.horizontal, 6)
            .background(CutShape(tight: 4, round: 14).fill(hovering ? Sobremesa.paperShade : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .overlay(alignment: .bottom) { Rectangle().fill(Sobremesa.ink.opacity(0.12)).frame(height: 1) }
        .accessibilityLabel("\(item.meta), \(item.entry.date.formatted(.dateTime.day().month().hour().minute())): \(item.firstWords)")
    }
}

/// Two faces of one card. The card turns over around its vertical axis.
struct FlipCard<Front: View, Back: View>: View {
    var flipped: Bool
    @ViewBuilder var front: () -> Front
    @ViewBuilder var back: () -> Back
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            front().modifier(FlipFace(angle: flipped ? 180 : 0, isBack: false))
            back().modifier(FlipFace(angle: flipped ? 180 : 0, isBack: true))
        }
        .animation(reduceMotion ? nil : .spring(response: 0.75, dampingFraction: 0.82), value: flipped)
    }
}

private struct FlipFace: ViewModifier, Animatable {
    nonisolated var angle: Double
    let isBack: Bool
    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    func body(content: Content) -> some View {
        let visible = isBack ? angle > 90 : angle <= 90
        content
            .rotation3DEffect(.degrees(isBack ? angle - 180 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}

struct ResultView: View {
    var snapshot: OverlaySnapshot
    var actions: PlateActions
    var actaController: ActaController? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Notice(text: snapshot.message ?? "Your words are kept.", error: true)
            if !snapshot.committedText.isEmpty {
                Text(snapshot.committedText).font(Sobremesa.display(16)).lineLimit(8).textSelection(.enabled)
                HStack(spacing: 12) {
                    Button("Copy words") { actions.copy(snapshot.committedText) }.buttonStyle(.printed(.primary, small: true))
                    Button("Export…") { actions.export(snapshot.committedText) }.buttonStyle(.printed(.secondary, small: true))
                }
            }
            HStack(spacing: 14) {
                if snapshot.pasteFailed { Button("Retry paste", action: actions.retryPaste).buttonStyle(.printed(.quiet, small: true)) }
                if snapshot.saveFailed { Button("Retry save", action: actions.retrySave).buttonStyle(.printed(.quiet, small: true)) }
                Button("Dismiss", action: actions.dismiss).buttonStyle(.printed(.quiet, small: true))
            }
        }
    }
}
