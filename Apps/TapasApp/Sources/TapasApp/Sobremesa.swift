import AppKit
import CoreText
import SwiftUI

/// Sobremesa design language. Spec: private/design/tapas/SOBREMESA.md.
/// Printed ink on bone paper, one tight corner, the four ingredients in big pieces.
enum Sobremesa {
    // The four ingredients are unchanged from Gráfico.
    static let saffron = Grafico.saffron
    static let cobalt = Grafico.cobalt
    static let paprika = Grafico.paprika
    static let olive = Grafico.olive
    static let ingredients = [saffron, cobalt, paprika, olive]

    static let ink = Color(red: 0x30 / 255, green: 0x3B / 255, blue: 0x2B / 255)
    static let deepInk = Color(red: 0x12 / 255, green: 0x16 / 255, blue: 0x0F / 255)
    static let paper = Color(red: 0xF5 / 255, green: 0xEE / 255, blue: 0xDF / 255)
    static let paperShade = Color(red: 0xEB / 255, green: 0xE1 / 255, blue: 0xCC / 255)
    /// Text on ink surfaces.
    static let paperOnInk = Color(red: 0xFB / 255, green: 0xF4 / 255, blue: 0xE4 / 255)
    static let muted = Color(red: 0x6A / 255, green: 0x6B / 255, blue: 0x57 / 255)
    static let saffronTint = Color(red: 0xF7 / 255, green: 0xE2 / 255, blue: 0xA0 / 255)

    static let outline: CGFloat = 1.6

    /// Fraunces with SOFT 100. Voices, headings, state labels. Falls back to the system serif.
    static func display(_ size: CGFloat, weight: CGFloat = 400, italic: Bool = false, wonky: Bool = true) -> Font {
        guard let base = italic ? FrauncesFonts.shared.italic : FrauncesFonts.shared.roman else {
            let fallback = Font.system(size: size, weight: weight >= 550 ? .semibold : .regular, design: .serif)
            return italic ? fallback.italic() : fallback
        }
        let axes: [NSNumber: NSNumber] = [
            FrauncesFonts.tag("wght"): NSNumber(value: Double(weight)),
            FrauncesFonts.tag("opsz"): NSNumber(value: Double(min(144, max(9, size)))),
            FrauncesFonts.tag("SOFT"): 100,
            FrauncesFonts.tag("WONK"): wonky ? 1 : 0,
        ]
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(base, [kCTFontVariationAttribute: axes] as CFDictionary)
        return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
    }
}

/// Registers the bundled variable Fraunces fonts once, for this process only.
final class FrauncesFonts: @unchecked Sendable {
    static let shared = FrauncesFonts()
    let roman: CTFontDescriptor?
    let italic: CTFontDescriptor?

    private init() {
        roman = Self.load("Fraunces")
        italic = Self.load("Fraunces-Italic")
    }

    static func tag(_ code: String) -> NSNumber {
        NSNumber(value: code.unicodeScalars.reduce(UInt32(0)) { ($0 << 8) | $1.value })
    }

    /// SwiftPM copies Resources/Fonts into TapasApp_TapasApp.bundle. The packaged app keeps
    /// that bundle in Contents/Resources; debug builds keep it next to the executable.
    static func fontsDirectory() -> URL? {
        let name = "TapasApp_TapasApp.bundle"
        let candidates = [Bundle.main.resourceURL, Bundle.main.executableURL?.deletingLastPathComponent()]
            .compactMap { $0?.appendingPathComponent(name) }
        // Use Bundle rather than a fixed layout: macOS resource bundles keep files in Contents/Resources.
        return candidates.lazy.compactMap { Bundle(url: $0)?.url(forResource: "Fonts", withExtension: nil) }.first
    }

    private static func load(_ name: String) -> CTFontDescriptor? {
        guard let url = fontsDirectory()?.appendingPathComponent("\(name).ttf"),
              let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { return nil }
        return descriptors.first
    }
}

/// A shape with one tight corner (Sobremesa: hand-cut shapes).
struct CutShape: Shape {
    var tight: CGFloat
    var round: CGFloat
    var corner: Corner = .topLeading
    enum Corner { case topLeading, topTrailing, hanging }

    func path(in rect: CGRect) -> Path {
        let radii: RectangleCornerRadii = switch corner {
        case .topLeading: .init(topLeading: tight, bottomLeading: round, bottomTrailing: round, topTrailing: round)
        case .topTrailing: .init(topLeading: round, bottomLeading: round, bottomTrailing: round, topTrailing: tight)
        // Hangs from the menu bar: both top corners tight.
        case .hanging: .init(topLeading: tight, bottomLeading: round, bottomTrailing: round, topTrailing: tight)
        }
        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous).path(in: rect)
    }
}

/// Printed material: fill, ink outline, and a hard offset ink shadow. Never blurred.
struct Printed<S: Shape>: ViewModifier {
    var shape: S
    var fill: Color = Sobremesa.paper
    var outline: Color? = Sobremesa.ink
    var shadow: Color = Sobremesa.ink
    var offset = CGSize(width: 4, height: 5)

    func body(content: Content) -> some View {
        content
            .background(shape.fill(fill))
            .overlay(outline.map { shape.inkBorder($0, lineWidth: Sobremesa.outline) }.allowsHitTesting(false))
            .background(shape.fill(shadow).offset(offset))
    }
}

extension View {
    func printed<S: Shape>(_ shape: S, fill: Color = Sobremesa.paper, outline: Color? = Sobremesa.ink,
                           shadow: Color = Sobremesa.ink, offset: CGSize = CGSize(width: 4, height: 5)) -> some View {
        modifier(Printed(shape: shape, fill: fill, outline: outline, shadow: shadow, offset: offset))
    }
}

extension Shape {
    /// An outline drawn inside the shape's bounds, for any shape (strokeBorder needs InsettableShape).
    func inkBorder(_ color: Color, lineWidth: CGFloat) -> some View {
        InsetStroke(shape: self, color: color, lineWidth: lineWidth)
    }
}

private struct InsetStroke<S: Shape>: View {
    var shape: S
    var color: Color
    var lineWidth: CGFloat
    var body: some View {
        GeometryReader { proxy in
            shape.path(in: CGRect(origin: .zero, size: proxy.size).insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
                .stroke(color, lineWidth: lineWidth)
        }
    }
}
