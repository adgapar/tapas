import SwiftUI
import TapasCore

@MainActor @Observable
final class SetupModel {
    var flow: SetupFlow
    var stage = 0
    var entered = false
    var isPresented = false
    var downloading = false
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
    init(flow: SetupFlow) {
        self.flow = flow
        entered = flow.phase != .peek
        switch flow.phase {
        case .peek: stage = 0
        case .microphone, .accessibility: stage = 1
        case .kitchen: stage = 2
        case .tryIt, .finished: stage = 3
        }
    }
}

struct SetupView: View {
    @Bindable var model: SetupModel
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
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
    var animateServing = true
    private var openingDoorState = SwiftUI.State<Bool>(initialValue: false)
    private var openingDoor: Bool {
        get { openingDoorState.wrappedValue }
        nonmutating set { openingDoorState.wrappedValue = newValue }
    }
    private var movingInsideState = SwiftUI.State<Bool>(initialValue: false)
    private var movingInside: Bool {
        get { movingInsideState.wrappedValue }
        nonmutating set { movingInsideState.wrappedValue = newValue }
    }
    private var leavingBarState = SwiftUI.State<Bool>(initialValue: false)
    private var leavingBar: Bool {
        get { leavingBarState.wrappedValue }
        nonmutating set { leavingBarState.wrappedValue = newValue }
    }

    private var servingReceipt: Bool { model.stage == 3 && model.completedPractice && !model.phase.isActive }
    private var objectID: String { servingReceipt ? "receipt" : "step-\(model.stage)" }

    var body: some View {
        VStack(spacing: 12) {
            if model.entered {
                ZStack(alignment: .top) {
                    SetupCounter()
                    // Keep the paper on a solid counter; the whole scene never scrolls.
                    VStack(spacing: 0) {
                        Spacer().frame(height: 52)
                        CounterServing(identity: objectID, paper: model.stage == 0 || servingReceipt, reducedMotion: reducedMotion || !animateServing) {
                        VStack(alignment: .leading, spacing: model.stage == 0 || servingReceipt ? 10 : 8) {
                            if servingReceipt { firstReceipt }
                            else {
                                if model.stage > 0 {
                                    HStack { Eyebrow(text: "tapas / your place"); Spacer(); Eyebrow(text: "\(model.stage) / 3") }
                                }
                                content
                                if let error = model.flow.modelError { NoticeBox(text: error, error: true) }
                                if model.stage > 0 {
                                    Spacer(minLength: 0)
                                    HStack {
                                        Button("← Back", action: onBack).disabled(model.phase.isActive || model.busy)
                                        Spacer()
                                        Button("Finish later", action: onSkip)
                                    }.font(.system(size: 11)).buttonStyle(.plain).padding(.top, 6)
                                }
                            }
                        }
                        .frame(width: model.stage == 0 || servingReceipt ? 300 : 410, alignment: .leading)
                        .frame(minHeight: model.stage > 0 && !servingReceipt ? 450 : nil, alignment: .top)
                        .padding(.horizontal, model.stage == 0 ? 26 : 22)
                        .padding(.vertical, model.stage == 0 ? 26 : 18)
                        .background {
                            if servingReceipt {
                                ReceiptPaper().fill(Grafico.card).shadow(color: Grafico.ink.opacity(0.18), radius: 9, x: 5, y: 12)
                            } else if model.stage == 0 {
                                RoundedRectangle(cornerRadius: 2).fill(Grafico.card)
                                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Grafico.ink.opacity(0.4), lineWidth: 0.8))
                                    .shadow(color: Grafico.ink.opacity(0.2), radius: 0, x: 2, y: 4)
                                    .shadow(color: Grafico.ink.opacity(0.18), radius: 12, x: 5, y: 14)
                            } else { SetupNapkin() }
                        }
                        .rotationEffect(.degrees(model.stage == 0 || servingReceipt ? -2 : -0.5))
                        .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 55)
                    }
                }
                .overlay(alignment: .bottom) { counterControls.padding(.horizontal, 28).padding(.bottom, 13) }
                .opacity(leavingBar ? 0 : 1)
            } else {
                entrance.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.padding(22)
            .frame(width: SetupWindowController.size.width, height: SetupWindowController.size.height)
            .overlay(alignment: .topTrailing) {
                if model.entered {
                    HStack(spacing: 12) {
                        Menu {
                            Button("Replay entrance") {
                                openingDoor = false; movingInside = false; model.entered = false
                            }.disabled(model.phase.isActive || model.busy)
                            Button("Finish later", action: onSkip)
                        } label: { Image(systemName: "ellipsis") }
                            .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Setup options")
                        ClosePlateButton(label: "Close welcome", action: onSkip)
                    }.padding(36)
                }
            }
            .foregroundStyle(Grafico.ink).preferredColorScheme(.light)
            .onChange(of: model.entered) { _, entered in if entered { onEntered() } }
            .task(id: openingDoor) {
                guard openingDoor else { return }
                do {
                    try await Task.sleep(for: .milliseconds(650))
                    withAnimation(.easeIn(duration: 0.7)) { movingInside = true }
                    try await Task.sleep(for: .milliseconds(750))
                    guard !Task.isCancelled, model.isPresented else { return }
                    model.entered = true
                } catch { /* Closing setup cancels the entrance instead of navigating later. */ }
            }
            .task(id: leavingBar) {
                guard leavingBar else { return }
                do {
                    if !reducedMotion { try await Task.sleep(for: .milliseconds(400)) }
                    guard !Task.isCancelled, model.isPresented else { return }
                    await onPrimary()
                } catch { }
            }
            .onChange(of: model.isPresented) { _, presented in
                if !presented { openingDoor = false; movingInside = false; leavingBar = false }
            }
            .onDisappear { openingDoor = false; movingInside = false; leavingBar = false }
    }

    private var counterControls: some View {
        BrandCredit(color: Grafico.card.opacity(0.8)).frame(maxWidth: .infinity)
    }

    private var entrance: some View {
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 95).fill(Grafico.olive.opacity(0.22))
                VStack(spacing: 20) {
                    Text("tapas /").font(.system(size: 30, weight: .bold)).foregroundStyle(Grafico.olive)
                    Rectangle().fill(Grafico.olive).frame(height: 8)
                    Rectangle().fill(Color(red: 0.64, green: 0.46, blue: 0.30)).frame(height: 120)
                }.padding(.top, 140).clipShape(DoorArch())
                Button(action: enterBar) {
                    ZStack(alignment: .trailing) {
                        DoorArch().fill(Grafico.paper.opacity(0.94))
                            .overlay(DoorArch().stroke(Grafico.ink, lineWidth: 2))
                        VStack(spacing: 13) {
                            PintxoMark().frame(width: 76, height: 106)
                            Text("tapas /").font(.system(size: 38, weight: .heavy)).tracking(-1.8)
                            Text("Come on in.").font(.system(size: 23, design: .serif)).italic().padding(.top, 6)
                            Text("A little room for your thoughts.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
                            Spacer(minLength: 10)
                            Eyebrow(text: "Push →")
                            BrandCredit().padding(.top, 4)
                        }.padding(.top, 42).padding(.bottom, 28).frame(maxWidth: .infinity)
                        Capsule().fill(Grafico.saffron.opacity(0.7)).overlay(Capsule().stroke(Grafico.ink, lineWidth: 1))
                            .frame(width: 9, height: 60).padding(.trailing, 21).offset(y: 70)
                    }
                }.buttonStyle(.plain).accessibilityLabel("Push the door to enter Tapas")
                    .disabled(openingDoor)
                    .rotation3DEffect(.degrees(openingDoor ? 100 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.45)
                    .animation(reducedMotion ? nil : .easeInOut(duration: 1.05), value: openingDoor)
            }.frame(width: 270, height: 410)
                .overlay(DoorArch().stroke(Grafico.olive, lineWidth: 11).allowsHitTesting(false))
                .shadow(color: Grafico.ink.opacity(0.17), radius: 10, x: 4, y: 8)
                .scaleEffect(movingInside ? 1.5 : 1).opacity(movingInside ? 0 : 1)
            HStack(spacing: 24) {
                Button("Close", action: onSkip)
                    .foregroundStyle(Grafico.muted)
                    .accessibilityLabel("Close welcome")
                Button("Skip entrance") { model.entered = true }
                    .fontWeight(.semibold)
                    .foregroundStyle(Grafico.ink)
                    .disabled(openingDoor)
            }
            .buttonStyle(.plain).font(.system(size: 12))
            .padding(.horizontal, 8).padding(.vertical, 2).floatingLabel()
        }
    }

    private func enterBar() {
        if reducedMotion { model.entered = true }
        else { openingDoor = true }
    }

    private var firstReceipt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "tapas / your first words")
            Text("Something\nto take with you.").font(.system(size: 28, design: .serif)).italic()
            ReceiptRule()
            ScrollView { Text(model.practiceText).font(.system(size: 20, design: .serif)).italic().lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 120)
            ReceiptRule()
            Text("One thought. In your own words.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            Button("Take it with you →") {
                withAnimation(reducedMotion ? nil : .easeIn(duration: 0.4)) { leavingBar = true }
            }.buttonStyle(GraficoButtonStyle()).disabled(leavingBar || model.busy)
            Button("Try another thought") { Task { await onPractice() } }.buttonStyle(.plain).font(.system(size: 11)).disabled(model.busy)
            Text("Practice stays here. Nothing was pasted or saved.").font(.system(size: 10)).foregroundStyle(Grafico.muted)
        }
    }

    @ViewBuilder private var content: some View {
        switch model.stage {
        case 0:
            Text("tapas /   SMALL TOOLS. GOOD COMPANY.").font(.system(size: 8, design: .monospaced)).tracking(0.6).foregroundStyle(Grafico.muted)
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome.").font(.system(size: 28, design: .serif))
                Text("This is your place.").font(.system(size: 28, design: .serif)).italic().foregroundStyle(BarPalette.color(0x77875f))
            }.padding(.top, 10)
            Text("A thought to put into words.\nA conversation worth keeping.").font(.system(size: 11)).lineSpacing(4).foregroundStyle(Grafico.muted).padding(.bottom, 8)
            menuTool("01", name: "Dictado", description: "Speak. Put your words where you work.", symbol: "◉")
            menuTool("02", name: "Acta", description: "Keep a conversation as a transcript.", symbol: "≋")
            ReceiptRule()
            Text("On your Mac. In your hands.").font(.system(size: 12, design: .serif)).italic().foregroundStyle(Grafico.muted).padding(.vertical, 4)
            Button("Let’s get you settled →") { Task { await onPrimary() } }.buttonStyle(GraficoButtonStyle()).disabled(model.busy)
        case 1:
            heading("A little access.")
            Text("Each permission has a purpose. You choose when to allow it.").font(.system(size: 13)).foregroundStyle(Grafico.muted)
            permission("Microphone", detail: "Your voice, for Dictado and Acta.", granted: model.flow.microphoneGranted) { Task { await onMicrophone() } }
            permission("Shortcuts & paste", detail: "Accessibility: both shortcuts + Dictado paste.", granted: model.flow.accessibilityTrusted, action: onSecondary)
            permission("Meeting audio · Acta", detail: "Screen & System Audio Recording.", granted: model.appAudioGranted) { Task { await onAppAudio() } }
            Text("Acta saves audio transcripts, never screen images. Meeting audio can wait until your first meeting. Buttons work without Accessibility.")
                .font(.system(size: 11)).foregroundStyle(Grafico.muted).lineSpacing(2)
            if model.accessibilityChecked && !model.flow.accessibilityTrusted {
                Text("Enable Tapas in System Settings → Privacy & Security → Accessibility, then check again.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
                Button("Show Tapas in Finder", action: onRevealApplication).buttonStyle(.plain)
            }
            Button("Check permissions again", action: onRecheckAccessibility).buttonStyle(.plain).font(.system(size: 11))
            primary("Continue →")
        case 2:
            heading("A home for your words.")
            Text("One shared folder for Dictado and Acta. Change it in Preferences anytime.").font(.system(size: 13)).foregroundStyle(Grafico.muted)
            HStack {
                Image(systemName: "folder").font(.system(size: 26)).foregroundStyle(Grafico.cobalt)
                Text(model.transcriptDirectory.path).font(.system(size: 11)).textSelection(.enabled)
                Spacer()
                Button("Choose…", action: onChooseFolder)
            }.padding(14).background(Grafico.paper, in: RoundedRectangle(cornerRadius: 9))
            Label("dictado · saved takes", systemImage: "folder").font(.system(size: 12))
            Label("acta · meeting transcripts", systemImage: "folder").font(.system(size: 12))
            Text("Tapas creates these subfolders for you. Existing files stay where they are.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
            if let error = model.folderError { NoticeBox(text: error, error: true) }
            if model.folderConfirmed { NoticeBox(text: "Folder selected. Both tools use this location.") }
            else { Button("Use Documents/tapas", action: onDefaultFolder).buttonStyle(GraficoButtonStyle(secondary: true)) }
            primary("Continue →", disabled: !model.folderConfirmed)
        default:
            HStack(spacing: 18) {
                PintxoWaveform(recording: model.phase == .listening, level: model.level)
                    .scaleEffect(0.58).frame(width: 76, height: 94)
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Try a little before you go")
                    heading("Say something small.")
                }
            }
            if !model.flow.modelsReady {
                Text("Prepare your local voice models once. Practice stays in this window.").font(.system(size: 13)).foregroundStyle(Grafico.muted)
                if model.downloading {
                    ProgressView(value: model.flow.downloadFraction).tint(Grafico.olive)
                    Text(model.flow.downloadFraction, format: .percent.precision(.fractionLength(0))).font(.system(size: 11, design: .monospaced))
                }
                Button(model.downloading ? "Preparing…" : "Prepare voice models") { Task { await onPrepare() } }.buttonStyle(GraficoButtonStyle()).disabled(model.downloading)
            } else if !model.flow.microphoneGranted {
                permission("Microphone", detail: "Allow it to try your first take.", granted: false) { Task { await onMicrophone() } }
            } else {
                Text("✓ Voice models ready on this Mac").font(.system(size: 11)).foregroundStyle(Grafico.olive)
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: model.phase == .listening ? "Listening" : model.completedPractice ? "Your words, ready" : "Say something like")
                    Text(model.practiceText.isEmpty ? "Leave a little room for the good ideas." : model.practiceText)
                        .font(.system(size: 18, design: .serif)).italic().lineLimit(3).textSelection(.enabled)
                    Button(model.phase == .listening ? "Finish practice take" : model.phase == .finishing ? "Finishing…" : "Try a practice take") { Task { await onPractice() } }
                        .buttonStyle(GraficoButtonStyle(secondary: true)).disabled(model.busy || model.phase == .finishing || model.phase == .starting)
                    if model.phase == .listening { Button("Cancel practice", action: onCancel).buttonStyle(.plain) }
                    Text("Nothing is pasted or saved during practice.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
                }
            }
            primary(model.completedPractice ? "Lovely. Let’s begin →" : "Open Tapas →", disabled: model.phase.isActive)
            Text("Acta suggests recording when another app uses your microphone. Recording is always your choice.").font(.system(size: 11)).foregroundStyle(Grafico.muted)
        }
    }

    private func heading(_ title: String) -> some View { Text(title).font(.system(size: 29, weight: .bold)).tracking(-0.8) }
    private func primary(_ title: String, disabled: Bool = false) -> some View {
        Button { Task { await onPrimary() } } label: { HStack { Text(title); Spacer() } }
            .buttonStyle(GraficoButtonStyle()).disabled(disabled || model.busy)
    }
    private func permission(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 13)); Text(detail).font(.system(size: 10)).foregroundStyle(Grafico.muted) }
            Spacer()
            if granted { Image(systemName: "checkmark.circle.fill").foregroundStyle(Grafico.olive).accessibilityLabel("Allowed") }
            else { Button("Allow →", action: action).buttonStyle(.plain).foregroundStyle(Grafico.cobalt).disabled(model.busy) }
        }.padding(.vertical, 5)
    }
    private func menuTool(_ number: String, name: String, description: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ReceiptRule()
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(number).font(.system(size: 8, design: .monospaced)).foregroundStyle(Grafico.muted)
                VStack(alignment: .leading, spacing: 8) {
                    Text(name).font(.system(size: 25, weight: .medium)).tracking(-0.9)
                    Text(description).font(.system(size: 10)).foregroundStyle(Grafico.muted)
                }
                Spacer(minLength: 0)
                Text(symbol).font(.system(size: 21)).foregroundStyle(Grafico.olive)
            }.padding(.bottom, 8)
        }
    }
}


private struct DoorArch: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, 95.0)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: rect.origin)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
