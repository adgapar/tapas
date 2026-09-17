import AppKit
import SwiftUI
import TapasCore

/// A regular, focusable app window with transparent space around its SwiftUI cards.
final class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
func configureFloatingWindow(_ window: NSWindow) {
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = false
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.appearance = NSAppearance(named: .aqua)
    window.collectionBehavior = [.moveToActiveSpace]
}

@MainActor
func placeFloatingWindow(_ window: NSWindow, preferred: NSSize) {
    let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    guard let area = screen?.visibleFrame else { return }
    let scale = min(1, (area.width - 32) / preferred.width, (area.height - 32) / preferred.height)
    window.setContentSize(NSSize(width: preferred.width * scale, height: preferred.height * scale))
    window.setFrameOrigin(NSPoint(x: area.midX - window.frame.width / 2, y: area.midY - window.frame.height / 2))
}

struct FittedSurface<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var content: () -> Content
    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / width, proxy.size.height / height)
            // Hosting views can propose zero size during initial layout. A zero
            // scale makes AppKit-backed scroll view transforms non-invertible.
            let safeScale = scale.isFinite && scale > 0 ? scale : 1
            content().frame(width: width, height: height)
                .scaleEffect(safeScale, anchor: .topLeading)
        }
    }
}

struct TapasWordmark: View {
    var size: CGFloat = 34
    var body: some View {
        HStack(spacing: 7) {
            PintxoMark().frame(width: size, height: size * 1.2)
            Text("tapas").font(.system(size: size, weight: .heavy)).tracking(-1.6)
            Text("/").font(.system(size: size, weight: .heavy)).foregroundStyle(Grafico.paprika)
        }.foregroundStyle(Grafico.ink).accessibilityElement(children: .ignore).accessibilityLabel("tapas")
    }
}

struct PlateSurface: ViewModifier {
    var color = Grafico.card
    func body(content: Content) -> some View {
        content.padding(20)
            .background {
                RoundedRectangle(cornerRadius: 17).fill(color)
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(Grafico.ink.opacity(0.85), lineWidth: 1))
                    .shadow(color: Grafico.ink.opacity(0.17), radius: 0, x: 3, y: 5)
            }
    }
}
extension View {
    func plateSurface(_ color: Color = Grafico.card) -> some View { modifier(PlateSurface(color: color)) }
    /// Separate light islands keep the floating composition readable on any wallpaper.
    func floatingLabel() -> some View {
        padding(10).background(Grafico.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ClosePlateButton: View {
    var label = "Close tapas"
    var action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 28, height: 28) }
            .buttonStyle(.plain).background(Grafico.card, in: Circle()).foregroundStyle(Grafico.ink)
            .accessibilityLabel(label)
    }
}

/// Four persistent ingredients morph into bars. Their heights use measured audio,
/// with a visible minimum during silence. Reduced motion retains a still Pintxo.
struct PintxoWaveform: View {
    var recording = false
    var level: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    // Explicit storage also builds with CLT SDKs that omit the SwiftUI macro plugin.
    private var appeared = SwiftUI.State<Bool>(initialValue: false)
    private let colors: [Color] = [Grafico.saffron, Grafico.cobalt, Grafico.paprika, Grafico.olive]
    var body: some View {
        let wave = recording && appeared.wrappedValue && !reducedMotion
        ZStack {
            Capsule().fill(Grafico.ink).frame(width: 2, height: 144)
                .opacity(wave ? 0 : 1)
            ForEach(0..<4) { index in
                let energy = CGFloat(max(0, min(1, level * (index % 2 == 0 ? 2.8 : 3.4))))
                let height = 25 + energy * 75
                RoundedRectangle(cornerRadius: PintxoArtwork.corner(index))
                    .fill(colors[index])
                    .overlay(RoundedRectangle(cornerRadius: PintxoArtwork.corner(index)).stroke(Grafico.ink, lineWidth: 1.8))
                    .frame(width: wave ? 18 : PintxoArtwork.widths[index], height: wave ? height : PintxoArtwork.height)
                    .shadow(color: Grafico.ink, radius: 0, x: 2, y: 3)
                    .offset(x: wave ? CGFloat(index) * 27 - 40.5 : 0,
                            y: wave ? 0 : CGFloat(index) * PintxoArtwork.spacing - 42)
                    .animation(reducedMotion ? nil : .linear(duration: 0.14), value: level)
            }
        }
        .rotationEffect(.degrees(wave ? 0 : PintxoArtwork.tilt))
        .frame(width: 120, height: 154)
        .animation(reducedMotion ? nil : .spring(response: 0.65, dampingFraction: 0.86), value: wave)
        .onAppear { appeared.wrappedValue = true }
        .accessibilityHidden(true)
    }
}

struct IngredientProgress: View {
    let step: Int
    private let names = ["Welcome", "A little access", "Your files", "First taste"]
    private let colors = [Grafico.saffron, Grafico.cobalt, Grafico.paprika, Grafico.olive]
    var body: some View {
        HStack {
            ForEach(0..<4) { index in
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: index == 0 ? 13 : 5)
                        .fill(colors[index].opacity(index == step ? 1 : 0.35))
                        .overlay(RoundedRectangle(cornerRadius: index == 0 ? 13 : 5).stroke(Grafico.ink, lineWidth: 1))
                        .frame(width: index == 3 ? 32 : 45, height: 25).rotationEffect(.degrees(index == step ? 0 : -8))
                    Text(names[index]).font(.system(size: 10, weight: index == step ? .semibold : .regular))
                }.frame(maxWidth: .infinity)
            }
        }.foregroundStyle(Grafico.ink).accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step + 1) of 4: \(names[step])")
    }
}
