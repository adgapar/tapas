import AppKit
import SwiftUI

/// Shared native surfaces. Production PintxoMark remains the identity source.
struct ReceiptPaper: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: rect.origin)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 6))
        let teeth = max(1, Int(rect.width / 10))
        let width = rect.width / CGFloat(teeth)
        for i in (0..<teeth).reversed() {
            path.addLine(to: CGPoint(x: rect.minX + CGFloat(i) * width + width / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + CGFloat(i) * width, y: rect.maxY - 6))
        }
        path.closeSubpath()
        return path
    }
}

struct ReceiptRule: View {
    var body: some View {
        Rectangle().fill(.clear).frame(height: 1)
            .overlay { GeometryReader { proxy in
                Path { path in path.move(to: .zero); path.addLine(to: CGPoint(x: proxy.size.width, y: 0)) }
                    .stroke(Grafico.ink.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            } }.accessibilityHidden(true)
    }
}

struct BrandCredit: View {
    var color: Color = Grafico.muted
    var body: some View {
        Link("Powered by Desert Ant Labs ↗", destination: URL(string: "https://desertant.com")!)
            .font(.system(size: 10)).foregroundStyle(color)
    }
}

struct ReceiptTrim: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach([Grafico.saffron, Grafico.cobalt, Grafico.paprika, Grafico.olive].indices, id: \.self) { i in
                [Grafico.saffron, Grafico.cobalt, Grafico.paprika, Grafico.olive][i]
            }
        }.frame(height: 5).accessibilityHidden(true)
    }
}

/// Colors and proportions shared with the approved bar-entry study.
enum BarPalette {
    static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    static let ambient = LinearGradient(colors: [color(0xc1c9b5), color(0xdfd6bd)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct SetupCounter: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Canvas { context, size in
                    // The bar is one continuous seated view, independent of the setup object.
                    context.scaleBy(x: size.width / 1040, y: size.height / 697)
                    context.translateBy(x: 0, y: -103)
                    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ hex: UInt32, _ alpha: Double = 1) {
                        context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(BarPalette.color(hex).opacity(alpha)))
                    }
                    func line(_ a: CGPoint, _ b: CGPoint, _ hex: UInt32, _ alpha: Double, _ width: CGFloat = 1) {
                        var p = Path(); p.move(to: a); p.addLine(to: b)
                        context.stroke(p, with: .color(BarPalette.color(hex).opacity(alpha)), lineWidth: width)
                    }
                    let stone = Path(CGRect(x: 0, y: 103, width: 1040, height: 636))
                    context.fill(stone, with: .linearGradient(Gradient(colors: [BarPalette.color(0xb9c9b0), BarPalette.color(0xced9c0)]), startPoint: CGPoint(x: 0, y: 103), endPoint: CGPoint(x: 350, y: 739)))
                    // Long diagonal mineral lines read as a countertop, not a flat green panel.
                    var mineralContext = context
                    mineralContext.clip(to: stone)
                    for y: CGFloat in [150, 315, 480, 645, 810] {
                        var vein = Path()
                        vein.move(to: CGPoint(x: 0, y: y))
                        vein.addLine(to: CGPoint(x: 1040, y: y - 105))
                        mineralContext.stroke(vein, with: .color(BarPalette.color(0xeff5e8).opacity(0.23)), lineWidth: 2)
                    }
                    for x: CGFloat in [125, 870] {
                        line(CGPoint(x: x, y: 103), CGPoint(x: x + 10, y: 739), 0x8ba17f, 0.16)
                    }
                    rect(0, 103, 1040, 3, 0xf4f4df)
                    rect(0, 739, 1040, 20, 0x9eac8c)
                    rect(0, 739, 1040, 3, 0xe7ebd8)
                    rect(0, 757, 1040, 2, 0x728162)
                    rect(0, 759, 1040, 41, 0x946d4a)
                    for x in stride(from: CGFloat(107), to: 1040, by: 109) { rect(x, 759, 2, 41, 0x60482d, 0.32) }
                    rect(0, 793, 1040, 7, 0x745438)
                    // Water glass: coaster, waterline, rim, transparent sides and a soft shadow.
                    context.translateBy(x: 95, y: 0)
                    let coaster = Path(ellipseIn: CGRect(x: 810, y: 330, width: 93, height: 62))
                    context.fill(coaster, with: .color(BarPalette.color(0xddd3b7).opacity(0.4)))
                    context.stroke(coaster, with: .color(BarPalette.color(0x9a9b78).opacity(0.25)), lineWidth: 1)
                    let glass = Path(roundedRect: CGRect(x: 827, y: 290, width: 58, height: 84), cornerRadius: 14)
                    context.fill(glass, with: .linearGradient(Gradient(colors: [.white.opacity(0.22), .white.opacity(0.04), .white.opacity(0.25)]), startPoint: CGPoint(x: 827, y: 290), endPoint: CGPoint(x: 885, y: 290)))
                    context.stroke(glass, with: .color(BarPalette.color(0xeff4e9).opacity(0.7)), lineWidth: 1)
                    let water = Path(roundedRect: CGRect(x: 831, y: 328, width: 50, height: 38), cornerRadius: 12)
                    context.fill(water, with: .color(BarPalette.color(0xe6f0dc).opacity(0.15)))
                    context.stroke(Path(ellipseIn: CGRect(x: 831, y: 325, width: 50, height: 14)), with: .color(.white.opacity(0.3)), lineWidth: 1)
                    let rim = Path(ellipseIn: CGRect(x: 827, y: 282, width: 58, height: 18))
                    context.fill(rim, with: .color(BarPalette.color(0xeef4e6).opacity(0.09)))
                    context.stroke(rim, with: .color(BarPalette.color(0xeff4e9).opacity(0.8)), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: Grafico.ink.opacity(0.25), radius: 16, x: 0, y: 10)
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

struct SetupNapkin: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5).fill(BarPalette.color(0xf5f0df))
            .overlay {
                Canvas { context, size in
                    var weave = Path()
                    for x in stride(from: CGFloat(0), to: size.width, by: 3) {
                        weave.move(to: CGPoint(x: x, y: 0)); weave.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: CGFloat(0), to: size.height, by: 3) {
                        weave.move(to: CGPoint(x: 0, y: y)); weave.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(weave, with: .color(BarPalette.color(0x817958).opacity(0.035)), lineWidth: 1)
                }.clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .overlay { RoundedRectangle(cornerRadius: 3).inset(by: 10).stroke(Grafico.cobalt.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [2, 2])) }
            .shadow(color: Grafico.ink.opacity(0.18), radius: 9, x: 5, y: 10)
    }
}

/// Perspective about the far edge of a sheet resting on the counter.
/// Project the entire object, including its text and controls, onto one plane.
struct CounterPerspective: GeometryEffect {
    var degrees: Double
    var animatableData: Double {
        get { degrees }
        set { degrees = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        let angle = degrees * .pi / 180
        let depth = sin(angle) / 1100
        var transform = ProjectionTransform(CGAffineTransform.identity)
        transform.m21 = -size.width / 2 * depth
        transform.m22 = cos(angle)
        transform.m23 = -depth
        return transform
    }
}

private struct ServingPose: ViewModifier {
    var pitch: Double
    var scale: CGFloat
    var y: CGFloat
    var opacity: Double
    func body(content: Content) -> some View {
        content.modifier(CounterPerspective(degrees: pitch))
            .scaleEffect(scale, anchor: .top)
            .offset(y: y).opacity(opacity)
    }
}

/// The old object clears first; the new one is then served into the same place.
/// SwiftUI retains the outgoing view by identity while its removal runs.
struct CounterServing<Content: View>: View {
    let identity: String
    let paper: Bool
    let reducedMotion: Bool
    @ViewBuilder var content: () -> Content
    private var arrived = SwiftUI.State(initialValue: false)
    private var ready = SwiftUI.State(initialValue: false)

    private var transition: AnyTransition {
        let rest = ServingPose(pitch: 0, scale: 1, y: 0, opacity: 1)
        let insertion = AnyTransition.modifier(
            active: ServingPose(pitch: 9, scale: 0.87, y: -58, opacity: 0), identity: rest
        ).animation(.timingCurve(0.2, 0.75, 0.2, 1, duration: 0.7).delay(0.24))
        let removal = AnyTransition.modifier(
            active: ServingPose(pitch: 5, scale: 0.96, y: -65, opacity: 0), identity: rest
        ).animation(.easeIn(duration: 0.22))
        return .asymmetric(insertion: insertion, removal: removal)
    }
    var body: some View {
        ZStack(alignment: .top) {
            if arrived.wrappedValue || reducedMotion {
                content().modifier(CounterPerspective(degrees: paper ? 10 : 8)).id(identity)
                    .transition(reducedMotion ? .identity : transition)
            }
        }.frame(maxWidth: .infinity, alignment: .top)
            .animation(reducedMotion ? nil : .easeInOut(duration: 0.7), value: identity)
            .allowsHitTesting(ready.wrappedValue)
            .task(id: identity) {
                ready.wrappedValue = false
                withAnimation(reducedMotion ? nil : .easeOut(duration: 0.7)) { arrived.wrappedValue = true }
                if !reducedMotion {
                    do { try await Task.sleep(for: .milliseconds(950)) }
                    catch { return }
                }
                guard !Task.isCancelled else { return }
                ready.wrappedValue = true
            }
    }
}
