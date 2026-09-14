import SwiftUI
import TapasCore

@MainActor
@Observable
final class SetupModel {
    var flow: SetupFlow
    var downloading = false
    var busy = false
    var practiceText = ""
    var listening = false
    var rms: Float = 0
    var topInset: CGFloat = 0

    init(flow: SetupFlow) {
        self.flow = flow
    }
}

private enum Ink {
    static let espresso = Color(red: 0.16, green: 0.10, blue: 0.07)
    static let card = Color(red: 0.23, green: 0.15, blue: 0.10)
    static let cream = Color(red: 0.97, green: 0.92, blue: 0.84)
    static let saffron = Color(red: 0.90, green: 0.56, blue: 0.22)
    static let stroke = Color(red: 0.94, green: 0.76, blue: 0.46)
}

struct SetupView: View {
    @Bindable var model: SetupModel
    var onPrimary: () async -> Void
    var onSecondary: () -> Void
    var onSkip: () -> Void
    var onPractice: () async -> Void
    var onPhaseChange: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if model.topInset > 0 {
                Capsule()
                    .fill(Ink.espresso)
                    .frame(width: 42, height: model.topInset + 8)
            }

            VStack(alignment: .leading, spacing: 10) {
                if model.flow.phase == .peek {
                    introHeader
                } else {
                    compactHeader
                }

                if model.flow.phase == .peek {
                    Text(model.flow.body)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Ink.cream.opacity(0.82))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Spacer()
                        primaryButton
                    }
                    .padding(.top, 4)
                }

                if let detail = model.flow.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.cream.opacity(0.45))
                }

                if model.flow.phase == .kitchen {
                    KitchenScene(fraction: model.flow.modelsReady ? 1 : model.flow.downloadFraction)
                    if !model.flow.modelsReady {
                        ProgressView(value: model.flow.downloadFraction)
                            .progressViewStyle(.linear)
                            .tint(Ink.saffron)
                    }
                }

                if model.flow.phase == .tryIt {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Ink.espresso.opacity(0.55))
                        if model.practiceText.isEmpty && !model.listening {
                            Text("Talk.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Ink.cream.opacity(0.35))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $model.practiceText)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(Ink.cream)
                            .padding(2)
                    }
                    .frame(height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Ink.stroke.opacity(0.35), lineWidth: 1)
                    )

                    Button {
                        Task { await onPractice() }
                    } label: {
                        Text(model.listening ? "Listening…" : model.busy ? "Starting…" : "Click to talk")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(model.listening ? Ink.espresso : Ink.cream)
                    .background(model.listening ? Ink.saffron : Ink.espresso, in: Capsule())
                    .disabled(model.busy && !model.listening)

                    HStack {
                        Spacer()
                        CommandKeycap(lit: model.listening, label: model.flow.hotkeyLabel)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Ink.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Ink.stroke.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 18, y: 8)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.22), value: model.flow.phase)
        .animation(.easeInOut(duration: 0.2), value: model.flow.downloadFraction)
        .onChange(of: model.flow.phase) { _, _ in
            onPhaseChange()
        }
    }

    private var introHeader: some View {
        HStack(spacing: 10) {
            PlateMark(lit: true, busy: false)
            Text(model.flow.speech)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Ink.cream)
            Spacer(minLength: 6)
            Button("Skip", action: onSkip)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Ink.cream.opacity(0.32))
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 10) {
            PlateMark(lit: model.listening, busy: model.flow.phase == .kitchen && !model.flow.modelsReady)

            Text(model.flow.speech)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Ink.cream)
                .lineLimit(1)

            Spacer(minLength: 6)

            if model.flow.phase != .peek {
                primaryButton
            }

            if let extra = model.flow.secondaryTitle {
                Button(extra, action: onSecondary)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Ink.cream.opacity(0.55))
            }

            if model.flow.phase != .finished {
                Button("Skip", action: onSkip)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Ink.cream.opacity(0.32))
            }
        }
    }

    private var primaryButton: some View {
        Group {
            if !model.flow.primaryTitle.isEmpty {
                Button {
                    Task { await onPrimary() }
                } label: {
                    Text(model.flow.primaryTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Ink.espresso)
                .background(Ink.saffron, in: Capsule())
                .disabled(model.busy)
                .opacity(model.busy ? 0.45 : 1)
            }
        }
    }
}

private struct PlateMark: View {
    var lit: Bool
    var busy: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: busy ? 1 / 20 : 1 / 6)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = busy ? 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 4.5)) : 1
            Canvas { context, size in
                let ink = Ink.saffron.opacity((lit ? 0.95 : 0.7) * pulse)
                var style = StrokeStyle(lineWidth: 1.6, lineCap: .round)
                let box = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 5)
                var outer = Path()
                outer.addEllipse(in: box)
                context.stroke(outer, with: .color(ink), style: style)
                style.lineWidth = 1.2
                var inner = Path()
                inner.addEllipse(in: box.insetBy(dx: 4, dy: 3))
                context.stroke(inner, with: .color(ink.opacity(0.8)), style: style)
            }
        }
        .frame(width: 22, height: 22)
    }
}

private struct KitchenScene: View {
    var fraction: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let saffron = Ink.saffron
                let cream = Ink.cream
                var stroke = StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)

                let pan = CGRect(x: 8, y: size.height * 0.42, width: 54, height: 18)
                var panPath = Path()
                panPath.addEllipse(in: pan)
                context.stroke(panPath, with: .color(saffron), style: stroke)
                var handle = Path()
                handle.move(to: CGPoint(x: pan.maxX - 2, y: pan.midY))
                handle.addLine(to: CGPoint(x: pan.maxX + 14, y: pan.midY - 2))
                context.stroke(handle, with: .color(saffron), style: stroke)

                stroke.lineWidth = 1.3
                for i in 0..<2 {
                    let x = pan.midX - 8 + CGFloat(i) * 14
                    var steam = Path()
                    let wobble = sin(t * 3 + Double(i) * 1.2) * 4
                    steam.move(to: CGPoint(x: x, y: pan.minY - 2))
                    steam.addQuadCurve(
                        to: CGPoint(x: x + wobble, y: 4),
                        control: CGPoint(x: x - 8 + wobble, y: pan.minY - 10)
                    )
                    context.stroke(steam, with: .color(cream.opacity(0.55)), style: stroke)
                }

                let hired = fraction >= 0.66 ? 3 : fraction >= 0.33 ? 2 : fraction > 0.04 ? 1 : 0
                for i in 0..<3 {
                    let x = 92 + CGFloat(i) * 28
                    let y = size.height * 0.38
                    let on = i < hired
                    var plate = Path()
                    plate.addEllipse(in: CGRect(x: x, y: y, width: 22, height: 10))
                    context.stroke(plate, with: .color(on ? saffron : cream.opacity(0.18)), style: stroke)
                    var rim = Path()
                    rim.addEllipse(in: CGRect(x: x + 4, y: y + 2, width: 14, height: 6))
                    context.stroke(rim, with: .color(on ? saffron.opacity(0.8) : cream.opacity(0.12)), style: stroke)
                }
            }
        }
        .frame(height: 48)
    }
}

private struct CommandKeycap: View {
    var lit: Bool
    var label: String

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 10)
            .frame(minWidth: 36, minHeight: 36)
            .foregroundStyle(lit ? Ink.espresso : Ink.cream.opacity(0.9))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(lit ? Ink.saffron : Ink.espresso.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Ink.stroke.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(lit ? 1.06 : 1)
            .animation(.easeInOut(duration: 0.15), value: lit)
    }
}
