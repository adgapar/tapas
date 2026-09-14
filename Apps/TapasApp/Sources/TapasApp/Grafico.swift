import AppKit
import SwiftUI
import TapasCore

/// Shared native interpretation of design/tapas: Pintxo / Gráfico.
enum Grafico {
    static let ink = Color(red: 0.188, green: 0.231, blue: 0.169)
    static let paper = Color(red: 0.953, green: 0.937, blue: 0.875)
    static let card = Color(red: 1, green: 0.982, blue: 0.925)
    static let saffron = Color(red: 0.941, green: 0.780, blue: 0.251)
    static let cobalt = Color(red: 0.200, green: 0.333, blue: 0.776)
    static let paprika = Color(red: 0.902, green: 0.373, blue: 0.231)
    static let olive = Color(red: 0.506, green: 0.576, blue: 0.310)
    static let muted = Color(red: 0.37, green: 0.42, blue: 0.29)
    static let tagline = "Small tools. Good company."
}

struct PintxoMark: View {
    var phase: DictationPhase = .idle
    var pieces = 4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion || !phase.isActive)) { timeline in
            Canvas { context, size in
                let scale = min(size.width / 100, size.height / 150)
                context.translateBy(x: size.width / 2, y: size.height / 2)
                context.scaleBy(x: scale, y: scale)
                context.rotate(by: .degrees(-19))
                var pick = Path()
                pick.move(to: CGPoint(x: 0, y: -72)); pick.addLine(to: CGPoint(x: 0, y: 72))
                context.stroke(pick, with: .color(Grafico.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let widths: [CGFloat] = [53, 67, 53, 38]
                let colors = [Grafico.saffron, Grafico.cobalt, Grafico.paprika, Grafico.olive]
                for i in 0..<4 {
                    let gap: CGFloat = phase == .listening ? 7 : 0
                    let y = CGFloat(i) * (29 + gap) - 54 - gap * 1.5
                    let dx: CGFloat = phase == .finishing || phase == .starting ? sin(time * 4 + Double(i)) * 5 : 0
                    let rect = CGRect(x: -widths[i] / 2 + dx, y: y, width: widths[i], height: 24)
                    let path = Path(roundedRect: rect, cornerRadius: i == 0 ? 12 : 4)
                    context.opacity = i < pieces ? 1 : 0.16
                    context.fill(Path(roundedRect: rect.offsetBy(dx: 2, dy: 3), cornerRadius: i == 0 ? 12 : 4), with: .color(Grafico.ink))
                    context.fill(path, with: .color(colors[i]))
                    context.stroke(path, with: .color(Grafico.ink), lineWidth: 1.8)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct GraficoButtonStyle: ButtonStyle {
    var blue = false
    var secondary = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(blue ? .white : Grafico.ink)
            .background(secondary ? Grafico.paper : blue ? Grafico.cobalt : Grafico.saffron, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Grafico.ink, lineWidth: 1))
            .compositingGroup()
            .shadow(color: Grafico.ink.opacity(isEnabled ? 0.85 : 0), radius: 0, x: configuration.isPressed ? 0 : 2, y: configuration.isPressed ? 0 : 3)
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(1.7).foregroundStyle(Grafico.muted)
    }
}

struct ToolGlyph: View {
    var symbol: String
    var color = Grafico.saffron
    var body: some View {
        Image(systemName: symbol).font(.system(size: 15, weight: .semibold))
            .frame(width: 36, height: 30).foregroundStyle(color == Grafico.cobalt ? .white : Grafico.ink)
            .background(color, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Grafico.ink, lineWidth: 1))
            .compositingGroup()
            .shadow(color: Grafico.ink, radius: 0, x: 2, y: 2)
            .accessibilityHidden(true)
    }
}

struct NoticeBox: View {
    var text: String
    var error = false
    var body: some View {
        Text(text).font(.system(size: 12)).lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background((error ? Grafico.paprika : Grafico.olive).opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke((error ? Grafico.paprika : Grafico.olive).opacity(0.45)))
    }
}
