import SwiftUI
import TapasCore

@MainActor @Observable
final class SetupModel {
    static let stepNames = ["Arrive", "Allow", "First take", "Acta", "House rules"]
    let assistant: AssistantSetupModel
    var flow: SetupFlow
    var stage = 0
    var entered = true
    var isPresented = false
    var downloading = false
    var preparationStatus = ModelPreparationStatus()
    var busy = false
    var practiceText = ""
    var phase: DictationPhase = .idle
    var level: Double = 0
    var completedPractice = false
    var accessibilityChecked = false
    var appAudioGranted = false
    var transcriptDirectory = TapasSettings().transcriptDirectory
    var folderConfirmed = false
    var folderError: String?
    init(flow: SetupFlow, assistant: AssistantSetupModel = AssistantSetupModel()) {
        self.assistant = assistant
        self.flow = flow
        switch flow.phase {
        case .peek, .kitchen: stage = 0
        case .microphone, .accessibility: stage = 1
        case .tryIt: stage = 2
        case .finished: stage = 4
        }
    }
}

/// Onboarding in Sobremesa: five short steps on tinted grounds. The pintxo fills in while
/// the speech model downloads, then stands up on its pick for the first take.
struct SetupView: View {
    @Bindable var model: SetupModel
    var plate: PlateModel = PlateModel()
    var actions: PlateActions = .inert
    var onPrimary: () async -> Void
    var onSecondary: () -> Void
    var onSkip: () -> Void
    var onPractice: () async -> Void
    var onCancel: () -> Void
    var onHotkey: (Hotkey) -> Void
    var onRecheckAccessibility: () -> Void = {}
    var onRevealApplication: () -> Void = {}
    var onBack: () -> Void = {}
    var onMicrophone: () async -> Void = {}
    var onAppAudio: () async -> Void = {}
    var onChooseFolder: () -> Void = {}
    var onDefaultFolder: () -> Void = {}
    var onPrepare: () async -> Void = {}
    var onEntered: () -> Void = {}
    var onAssistantAction: (String) -> Void = { _ in }
    var onStep: (Int) -> Void = { _ in }
    var autoPrepare = true

    private static let grounds = [Sobremesa.saffronTint, Sobremesa.cobaltTint, Sobremesa.paprikaTint, Sobremesa.oliveTint, Sobremesa.paper]
    private var card: CGSize { CGSize(width: SetupWindowController.size.width - 24, height: SetupWindowController.size.height - 24) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(alignment: model.stage == 4 ? .top : .center, spacing: 30) {
                art.frame(width: model.stage == 4 ? 130 : 270)
                VStack(alignment: .leading, spacing: 16) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 30).padding(.trailing, 44).padding(.vertical, 18)
            .frame(maxHeight: .infinity, alignment: model.stage == 4 ? .top : .center)
        }
        .frame(width: card.width, height: card.height)
        .background(CutShape(tight: 8, round: 34).fill(Self.grounds[min(4, model.stage)]))
        .animation(.easeInOut(duration: 0.5), value: model.stage)
        .clipShape(CutShape(tight: 8, round: 34))
        .overlay(CutShape(tight: 8, round: 34).inkBorder(Sobremesa.ink, lineWidth: Sobremesa.outline))
        .background(CutShape(tight: 8, round: 34).fill(Sobremesa.ink).offset(x: 6, y: 7))
        .frame(width: SetupWindowController.size.width, height: SetupWindowController.size.height, alignment: .topLeading)
        .padding(.leading, 4).padding(.top, 4)
        .foregroundStyle(Sobremesa.ink)
        .preferredColorScheme(.light)
        .task(id: model.stage) {
            if autoPrepare, model.stage == 0, !model.flow.modelsReady, !model.downloading, model.flow.modelError == nil { await onPrepare() }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 18) {
            ForEach(Array(SetupModel.stepNames.enumerated()), id: \.offset) { index, name in
                Button { onStep(index) } label: {
                    HStack(spacing: 8) {
                        CutShape(tight: 2, round: 4)
                            .fill(index == model.stage ? Sobremesa.ink : index < model.stage ? Sobremesa.olive : Sobremesa.paper)
                            .overlay(CutShape(tight: 2, round: 4).inkBorder(Sobremesa.ink, lineWidth: 1.3))
                            .frame(width: 13, height: 9).rotationEffect(.degrees(-19))
                        Text(name).font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(index == model.stage ? Sobremesa.ink : Sobremesa.muted)
                    }
                }
                .buttonStyle(.plain)
                .disabled(index > model.stage || model.phase.isActive || model.busy)
                .accessibilityLabel("Step \(index + 1) of 5, \(name)")
            }
            Spacer()
            modelChip
            Button(action: onSkip) { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).frame(width: 26, height: 26) }
                .buttonStyle(.plain).accessibilityLabel("Finish setup later")
        }
        .padding(.leading, 30).padding(.trailing, 20).padding(.top, 22)
    }

    private var downloadFraction: Double? {
        if model.flow.modelsReady { return nil }
        if model.downloading, model.preparationStatus.phase == .preparing { return 1 }
        return model.preparationStatus.fraction ?? model.flow.downloadFraction
    }

    private var modelChip: some View {
        Group {
            if model.flow.modelsReady { DoneMark(text: "Speech model ready") }
            else {
                HStack(spacing: 8) {
                    Text(model.downloading && model.preparationStatus.phase == .preparing ? "Preparing on this Mac" : "Speech model")
                    ZStack(alignment: .leading) {
                        CutShape(tight: 2, round: 4).fill(Sobremesa.paper)
                        CutShape(tight: 2, round: 4).fill(Sobremesa.saffron).frame(width: 64 * (downloadFraction ?? 0))
                    }
                    .frame(width: 64, height: 7)
                    .overlay(CutShape(tight: 2, round: 4).inkBorder(Sobremesa.ink, lineWidth: 1.2))
                }.font(.system(size: 11.5, weight: .semibold))
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .printed(CutShape(tight: 3, round: 10), offset: CGSize(width: 2, height: 3))
    }

    // MARK: Art

    @ViewBuilder private var art: some View {
        switch model.stage {
        case 2 where model.phase == .listening:
            SkewerPintxo(form: .standing(split: false), level: CGFloat(model.level)).frame(width: 250, height: 250)
        case 2 where model.phase == .finishing || model.phase == .starting:
            SkewerPintxo(form: .working).frame(width: 250, height: 250)
        case 3:
            TimelineView(.animation(minimumInterval: 1 / 10)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let you = Int(t / 2.6) % 5 == 0 || Int(t / 2.6) % 5 == 3
                let wave = CGFloat(0.45 + 0.4 * abs(sin(t * 3.3)))
                SkewerPintxo(form: .standing(split: true), level: you ? wave : 0.02, others: you ? 0.02 : wave)
            }.frame(width: 250, height: 250)
        case 4:
            SkewerPintxo(form: .resting).frame(width: 130, height: 130)
        default:
            SkewerPintxo(form: .resting, progress: model.stage <= 2 ? downloadFraction : nil).frame(width: 250, height: 250)
        }
    }

    // MARK: Steps

    private func headline(_ text: String) -> some View {
        Text(text).font(Sobremesa.display(42, weight: 600)).lineSpacing(-2).fixedSize(horizontal: false, vertical: true)
    }

    private func sub(_ text: String) -> some View {
        Text(text).font(.system(size: 15)).foregroundStyle(Sobremesa.ink.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
    }

    private func next(_ title: String = "Next", kind: PrintedButtonStyle.Kind = .primary, disabled: Bool = false) -> some View {
        Button(title) { Task { await onPrimary() } }.buttonStyle(.printed(kind)).disabled(disabled || model.busy || model.phase.isActive)
    }

    private var back: some View {
        Button("Back", action: onBack).buttonStyle(.printed(.quiet)).disabled(model.phase.isActive || model.busy)
    }

    @ViewBuilder private var content: some View {
        switch model.stage {
        case 0: arrive
        case 1: allow
        case 2: firstTake
        case 3: acta
        default: houseRules
        }
    }

    @ViewBuilder private var arrive: some View {
        headline("Your voice, written down and kept on this Mac.")
        if model.flow.modelsReady {
            Text("Ready. Everything runs on this Mac.").font(.system(size: 13, weight: .semibold))
        } else if model.downloading {
            Text(model.preparationStatus.title + (model.preparationStatus.fraction.map { " · \(Int($0 * 100))%" } ?? ""))
                .font(.system(size: 13, weight: .semibold))
        }
        sub("This happens once. Nothing you say leaves your Mac.")
        if let error = model.flow.modelError {
            Notice(text: error, error: true)
            Button("Try again") { Task { await onPrepare() } }.buttonStyle(.printed(.secondary, small: true)).disabled(model.downloading)
        }
        HStack(spacing: 16) { next(model.flow.modelsReady ? "Next" : "Continue while it downloads") }.padding(.top, 4)
    }

    private func permission(_ title: String, _ detail: String, granted: Bool, allow: String, primary: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Sobremesa.display(19, weight: 600))
                Text(detail).font(.system(size: 13)).foregroundStyle(Sobremesa.ink.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if granted { DoneMark(text: "Allowed") }
            else { Button(allow, action: action).buttonStyle(.printed(primary ? .primary : .secondary, small: true)).disabled(model.busy) }
        }.padding(.vertical, 12)
    }

    @ViewBuilder private var allow: some View {
        headline("Two permissions, each for one thing.")
        VStack(spacing: 0) {
            permission("Microphone", "So tapas can hear you.", granted: model.flow.microphoneGranted, allow: "Allow", primary: true) {
                Task { await onMicrophone() }
            }
            Rectangle().fill(Sobremesa.ink.opacity(0.14)).frame(height: 1)
            permission("Accessibility", "So your shortcut works in every app and your words can be pasted.",
                       granted: model.flow.accessibilityTrusted, allow: "Open System Settings", primary: false, action: onSecondary)
            Rectangle().fill(Sobremesa.ink.opacity(0.14)).frame(height: 1)
            permission("Meeting audio", "We’ll ask the first time you keep a call.",
                       granted: model.appAudioGranted, allow: "Allow now", primary: false) { Task { await onAppAudio() } }
        }
        .padding(.horizontal, 20).padding(.vertical, 4)
        .printed(CutShape(tight: 5, round: 22))
        if model.accessibilityChecked && !model.flow.accessibilityTrusted {
            HStack(spacing: 14) {
                Text("Turn on tapas in Privacy & Security → Accessibility.").font(.system(size: 12.5))
                Button("Show tapas in Finder", action: onRevealApplication).buttonStyle(.printed(.quiet, small: true))
                Button("Check again", action: onRecheckAccessibility).buttonStyle(.printed(.quiet, small: true))
            }
        }
        if let error = model.flow.modelError, model.stage == 1 { Notice(text: error, error: true) }
        HStack(spacing: 16) { back; next() }.padding(.top, 4)
    }

    @ViewBuilder private var firstTake: some View {
        if !model.flow.modelsReady {
            headline("Almost ready.")
            Text(model.downloading ? model.preparationStatus.title : "The speech model is on its way.").font(.system(size: 13, weight: .semibold))
            sub("You can try your first take as soon as the speech model is ready.")
            HStack(spacing: 16) { back; next("Skip for now") }.padding(.top, 4)
        } else if !model.flow.microphoneGranted {
            headline("First, the microphone.")
            sub("tapas needs to hear you for your first take.")
            HStack(spacing: 16) {
                back
                Button("Allow microphone") { Task { await onMicrophone() } }.buttonStyle(.printed(.primary)).disabled(model.busy)
            }.padding(.top, 4)
        } else if model.completedPractice && !model.phase.isActive {
            Text(model.practiceText).font(Sobremesa.display(26)).lineLimit(4).textSelection(.enabled)
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .printed(CutShape(tight: 5, round: 22))
            Text("That’s Dictado. It types wherever your cursor is.").font(Sobremesa.display(30, weight: 600)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Button("Try again") { Task { await onPractice() } }.buttonStyle(.printed(.secondary)).disabled(model.busy)
                next()
            }.padding(.top, 4)
        } else {
            HStack(alignment: .center, spacing: 10) {
                Text("Press").font(Sobremesa.display(42, weight: 600))
                ShortcutMenu(label: model.flow.hotkeyLabel, recording: plate.recordingShortcut, accessibilityName: "Dictado",
                             presets: [("Control–Option", { actions.setHotkey(.standard) }), ("Right Command", { actions.setHotkey(.rightCommand) })],
                             record: actions.recordHotkey, large: true)
                    .disabled(model.phase.isActive)
            }
            headline("and say anything.")
            if let error = plate.shortcutError { Notice(text: error, error: true) }
            Text(model.practiceText.isEmpty ? (model.phase == .listening ? "Listening…" : "Your words will appear here.") : model.practiceText)
                .font(Sobremesa.display(model.practiceText.isEmpty ? 18 : 24))
                .foregroundStyle(model.practiceText.isEmpty ? Sobremesa.muted : Sobremesa.ink)
                .lineLimit(4)
                .padding(18).frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
                .printed(CutShape(tight: 5, round: 22))
            HStack(spacing: 16) {
                back
                Button(model.phase == .listening ? "Done" : model.phase == .finishing ? "Finishing…" : "Start") { Task { await onPractice() } }
                    .buttonStyle(.printed(.primary)).disabled(model.busy || model.phase == .finishing || model.phase == .starting)
                if model.phase == .listening { Button("Cancel", action: onCancel).buttonStyle(.printed(.quiet)) }
                else { next("Skip", kind: .quiet) }
            }.padding(.top, 4)
            Text("Press the keys again, or Done, when you’re finished. Click the keys to use your own shortcut. Nothing is pasted or saved.")
                .font(.system(size: 12.5)).foregroundStyle(Sobremesa.ink.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
        }
        if let error = model.flow.modelError, model.stage == 2 { Notice(text: error, error: true) }
    }

    @ViewBuilder private var acta: some View {
        headline("For calls, there’s Acta.")
        sub("You stand up on the left, everyone else on the right. Nothing records until you say so.")
        VStack(spacing: 0) {
            RuleRow(toggle: Binding(get: { plate.settings.meetingPromptsEnabled },
                                    set: { plate.settings.meetingPromptsEnabled = $0; actions.preferencesChanged() }),
                    toggleColor: Sobremesa.cobalt, toggleLabel: "Offer to keep calls") {
                Text("When another app starts using my microphone, offer to keep the call.")
            }
            RuleRow(toggle: nil) {
                HStack(spacing: 6) {
                    Text("Open Acta with")
                    ShortcutMenu(label: plate.settings.actaHotkey.label, recording: plate.recordingActaShortcut, accessibilityName: "Acta",
                                 presets: [("Control–Shift–M", actions.resetActaHotkey)], record: actions.recordActaHotkey)
                    Text(".")
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 2)
        .printed(CutShape(tight: 5, round: 22))
        if let error = plate.shortcutError { Notice(text: error, error: true) }
        HStack(spacing: 16) { back; next() }.padding(.top, 4)
    }

    @ViewBuilder private var houseRules: some View {
        Text("These are your house rules.").font(Sobremesa.display(36, weight: 600))
        sub("Change them any time from the tapas pintxo in the menu bar.")
        ScrollView {
            HouseRulesView(model: plate, actions: actions, sections: [.dictado, .files, .assistant])
                .padding(.horizontal, 18).padding(.bottom, 12)
        }
        .scrollIndicators(.never)
        .frame(maxHeight: 330)
        .printed(CutShape(tight: 5, round: 22))
        HStack(spacing: 16) { back; next("Start using tapas") }.padding(.top, 4)
    }
}

extension PlateActions {
    /// Actions that do nothing, for previews and design renders.
    static var inert: PlateActions {
        PlateActions(talk: {}, setup: {}, setHotkey: { _ in }, recordHotkey: {}, preferencesChanged: {}, folder: {}, copy: { _ in },
                     export: { _ in }, dismiss: {}, retryPaste: {}, retrySave: {}, cancel: {}, quit: {})
    }
}
