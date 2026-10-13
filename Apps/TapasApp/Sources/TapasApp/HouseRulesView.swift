import AppKit
import SwiftUI
import TapasCore

/// Settings as sentences. Only what the app can change today (SOBREMESA.md, House rules).
/// The same rows appear in onboarding and on the back of the home card.
struct HouseRulesView: View {
    enum Section: CaseIterable { case dictado, acta, files, assistant, updates, about }
    @Bindable var model: PlateModel
    var actions: PlateActions
    var sections: [Section] = Section.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = model.shortcutError { Notice(text: error, error: true).padding(.vertical, 8) }
            ForEach(sections, id: \.self) { section in
                switch section {
                case .dictado: dictado
                case .acta: acta
                case .files: files
                case .assistant: assistant
                case .updates: if model.updates.available { updates }
                case .about: about
                }
            }
        }
    }

    private func group(_ title: String) -> some View {
        GroupLabel(text: title).padding(.top, 18).padding(.bottom, 2)
    }

    private func binding(_ keyPath: WritableKeyPath<TapasSettings, Bool>) -> Binding<Bool> {
        Binding(get: { model.settings[keyPath: keyPath] },
                set: { model.settings[keyPath: keyPath] = $0; actions.preferencesChanged() })
    }

    @ViewBuilder private var dictado: some View {
        group("Dictado")
        RuleRow(toggle: nil) {
            HStack(alignment: .center, spacing: 6) {
                Text("Press")
                ShortcutMenu(label: model.settings.hotkey.label, recording: model.recordingShortcut, accessibilityName: "Dictado",
                             presets: [("Control–Option", { actions.setHotkey(.standard) }), ("Right Command", { actions.setHotkey(.rightCommand) })],
                             record: actions.recordHotkey)
                    .disabled(model.snapshot.phase.isActive)
                Text("to start writing,")
            }
        } below: {
            Text("and press again to put the words into the app in front of me.")
                .font(Sobremesa.display(17)).foregroundStyle(Sobremesa.ink)
            if !model.accessibilityTrusted || !model.shortcutRunning {
                Button("Needs Accessibility to paste · Allow", action: actions.openAccessibility)
                    .buttonStyle(.printed(.secondary, small: true))
            }
        } trailing: { EmptyView() }
        RuleRow(toggle: binding(\.overlayEnabled), toggleColor: Sobremesa.saffron, toggleLabel: "Show my words while I speak") {
            Text("Show my words while I speak.")
        }
        RuleRow(toggle: binding(\.historyEnabled), toggleColor: Sobremesa.saffron, toggleLabel: "Keep a copy of each take") {
            Text("Keep a copy of each take, with private details removed.")
        }
    }

    @ViewBuilder private var acta: some View {
        group("Acta")
        RuleRow(toggle: binding(\.meetingPromptsEnabled), toggleColor: Sobremesa.cobalt, toggleLabel: "Offer to keep calls") {
            Text("When another app starts using my microphone, offer to keep the call.")
        }
        if let error = model.meetingDetectionError { Notice(text: error, error: true).padding(.vertical, 6) }
        RuleRow(toggle: nil) {
            HStack(alignment: .center, spacing: 6) {
                Text("Open Acta with")
                ShortcutMenu(label: model.settings.actaHotkey.label, recording: model.recordingActaShortcut, accessibilityName: "Acta",
                             presets: [("Control–Shift–M", actions.resetActaHotkey)], record: actions.recordActaHotkey)
                    .disabled(model.snapshot.phase.isActive)
                Text(".")
            }
        } below: {
            Text("It only starts recording when I say so.").font(Sobremesa.display(17)).foregroundStyle(Sobremesa.ink)
        } trailing: { EmptyView() }
    }

    @ViewBuilder private var files: some View {
        group("Your files")
        RuleRow(toggle: nil) {
            Text("Save recordings in")
        } below: {
            Menu {
                Button("Choose a folder…", action: actions.chooseFolder)
                Button("Open in Finder", action: actions.folder)
                Button("Use Documents/tapas", action: actions.resetFolder)
            } label: {
                Text(model.settings.transcriptDirectory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(Sobremesa.display(17, italic: true)).foregroundStyle(Sobremesa.ink)
                    .padding(.bottom, 1)
                    .overlay(alignment: .bottom) { Rectangle().fill(Sobremesa.saffron).frame(height: 2) }
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel("Transcript folder, \(model.settings.transcriptDirectory.path)")
            if let error = model.folderError { Notice(text: error, error: true) }
        } trailing: { EmptyView() }
    }

    @ViewBuilder private var assistant: some View {
        group("Your assistant")
        ForEach(AssistantHost.allCases) { host in
            let state = model.assistant.state(for: host)
            RuleRow(toggle: nil) {
                Text("Teach \(host.label) how to use my recordings and templates.")
            } below: { EmptyView() } trailing: {
                AssistantAction(state: state, host: host, act: actions.assistantAction)
            }
            .opacity(state == .absent ? 0.55 : 1)
        }
        if let message = model.assistant.message {
            Text(message).font(.system(size: 12)).foregroundStyle(Sobremesa.muted)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled).padding(.top, 8)
        }
        HStack(spacing: 12) {
            Button("Open templates") { actions.assistantAction("templates") }.buttonStyle(.printed(.secondary, small: true))
            Button("Rebuild recording index") { actions.assistantAction("rebuild") }.buttonStyle(.printed(.secondary, small: true))
            Button("Copy setup command") { actions.assistantAction("copy") }.buttonStyle(.printed(.quiet, small: true))
        }.padding(.top, 12).padding(.leading, 56)
        if let message = model.indexMessage {
            Text(message).font(.system(size: 12)).foregroundStyle(Sobremesa.muted).padding(.leading, 56).padding(.top, 6)
        }
    }

    @ViewBuilder private var updates: some View {
        group("Updates")
        RuleRow(toggle: Binding(get: { model.updates.automaticallyChecks }, set: { actions.setUpdateChecks($0) }),
                toggleColor: Sobremesa.olive, toggleLabel: "Check for updates automatically") {
            Text("Check for updates automatically.")
        }
        RuleRow(toggle: Binding(get: { model.updates.automaticallyDownloads }, set: { actions.setUpdateDownloads($0) }),
                toggleColor: Sobremesa.olive, toggleLabel: "Download updates automatically") {
            Text("Download them automatically too.")
        }.disabled(!model.updates.automaticallyChecks)
        if model.updates.waitingForRecording {
            Notice(text: "An update is ready. Finish or recover your recording before tapas restarts.").padding(.vertical, 6)
        }
        Button("Check for Updates…", action: actions.checkForUpdates).buttonStyle(.printed(.secondary, small: true))
            .disabled(!model.updates.canCheck).padding(.top, 12).padding(.leading, 56)
    }

    private var about: some View {
        Text("25 European languages, detected automatically. Voice processing stays on this Mac.")
            .font(.system(size: 12)).foregroundStyle(Sobremesa.muted).padding(.top, 20)
    }
}

/// Installing a skill is an action with real states, so it gets a button, not a switch.
struct AssistantAction: View {
    var state: AssistantSetupModel.State
    var host: AssistantHost
    var act: (String) -> Void
    var body: some View {
        switch state {
        case .absent:
            Text("Not on this Mac").font(.system(size: 12, weight: .semibold)).foregroundStyle(Sobremesa.muted).fixedSize()
        case .missing:
            Button("Install") { act("install:\(host.rawValue)") }.buttonStyle(.printed(.primary, small: true))
                .accessibilityLabel("Install the tapas skill for \(host.label)")
        case .update:
            Button("Update") { act("install:\(host.rawValue)") }.buttonStyle(.printed(.secondary, small: true))
                .accessibilityLabel("Update the tapas skill for \(host.label)")
        case .installed:
            HStack(spacing: 12) {
                DoneMark(text: "Installed")
                Button("Remove") { act("remove:\(host.rawValue)") }.buttonStyle(.printed(.quiet, small: true))
                    .accessibilityLabel("Remove the tapas skill from \(host.label)")
            }.fixedSize()
        case .attention(let message):
            Text(message).font(.system(size: 11)).foregroundStyle(Sobremesa.paprika).frame(maxWidth: 150, alignment: .trailing)
        }
    }
}
