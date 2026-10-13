import SwiftUI
import TapasCore

/// What the pintxo is doing. Sobremesa §4: the skewer is the baseline.
enum PintxoForm: Equatable {
    /// On its tilted pick, the way the mark always looks.
    case resting
    /// The pick swings flat and the pieces stand up on it. `split` puts you on the
    /// left (saffron, cobalt) and others on the right (paprika, olive).
    case standing(split: Bool)
    /// Back on the tilted pick, wobbling while work finishes.
    case working
}

/// One piece in artwork units. The artwork is a 150 × 150 square with its centre at (75, 75).
struct PintxoPiece: Equatable {
    var center: CGPoint
    var length: CGFloat
    var thickness: CGFloat
    var degrees: Double
    var corner: CGFloat
}

/// Pure geometry, so the transformation can be tested without rendering.
enum PintxoLayout {
    static let lengths: [CGFloat] = [53, 67, 53, 38]
    static let tilt = -19.0
    /// Rotating a piece to -90° stands it upright; the pick rotates the same way to lie flat.
    static let upright = -90.0

    static func pickDegrees(_ form: PintxoForm) -> Double {
        if case .standing = form { return upright }
        return tilt
    }

    static func pickLength(_ form: PintxoForm) -> CGFloat {
        if case .standing = form { return 136 }
        return 146
    }

    /// - Parameters:
    ///   - levels: 0...1 per piece, used only while standing.
    ///   - wobble: horizontal offset per piece, used only while working.
    static func pieces(_ form: PintxoForm, levels: [CGFloat] = [0, 0, 0, 0], wobble: [CGFloat] = [0, 0, 0, 0]) -> [PintxoPiece] {
        let radians = tilt * .pi / 180
        return (0..<4).map { i in
            switch form {
            case .standing(let split):
                let gap: CGFloat = split ? (i < 2 ? -7 : 7) : 0
                let level = min(1, max(0, levels[safe: i] ?? 0))
                return PintxoPiece(center: CGPoint(x: 75 + (CGFloat(i) - 1.5) * 29 + gap, y: 75),
                                   length: 22 + level * lengths[i] * 1.15, thickness: 21,
                                   degrees: upright, corner: i == 0 ? 10.5 : 7)
            case .resting, .working:
                let along = (CGFloat(i) - 1.45) * 29
                let dx = form == .working ? (wobble[safe: i] ?? 0) : 0
                // Positions along a pick tilted by `tilt` (screen y points down).
                return PintxoPiece(center: CGPoint(x: 75 - along * sin(radians) + dx, y: 75 + along * cos(radians)),
                                   length: lengths[i], thickness: 24, degrees: tilt, corner: i == 0 ? 12 : 4)
            }
        }
    }

    /// How much of piece `index` is colored while the speech model downloads (pieces fill in order).
    static func fill(progress: Double, index: Int) -> Double {
        min(1, max(0, progress * 4 - Double(index)))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// The printed pintxo: ink outline and a hard offset ink shadow on every piece.
struct SkewerPintxo: View {
    var form: PintxoForm = .resting
    /// 0...1 voice level. For a split call, `others` drives the right pair.
    var level: CGFloat = 0
    var others: CGFloat = 0
    /// Download progress. `nil` means fully colored.
    var progress: Double?
    /// On ink surfaces the outline and shadow switch to deep ink and the pick to paper.
    var onInk = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ink: Color { onInk ? Sobremesa.deepInk : Sobremesa.ink }
    private var animating: Bool {
        guard !reduceMotion else { return false }
        if case .resting = form { return false }
        return true
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: !animating)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let unit = min(proxy.size.width, proxy.size.height) / 150
                let origin = CGPoint(x: (proxy.size.width - 150 * unit) / 2, y: (proxy.size.height - 150 * unit) / 2)
                let pieces = PintxoLayout.pieces(form, levels: levels(at: time), wobble: wobble(at: time))
                ZStack {
                    Capsule().fill(onInk ? Sobremesa.paperOnInk.opacity(0.8) : Sobremesa.ink)
                        .frame(width: max(1.5, 2 * unit), height: PintxoLayout.pickLength(form) * unit)
                        .rotationEffect(.degrees(PintxoLayout.pickDegrees(form)))
                        .position(x: origin.x + 75 * unit, y: origin.y + 75 * unit)
                    // A drawn ink layer, not .shadow: printed shadows are hard, and must not
                    // depend on how a renderer orients its coordinate space.
                    let shadow = CGSize(width: max(1, 2 * unit), height: max(1.5, 3 * unit))
                    ForEach(0..<4, id: \.self) { i in
                        let piece = pieces[i]
                        RoundedRectangle(cornerRadius: min(piece.corner, piece.thickness / 2) * unit, style: .circular).fill(ink)
                            .frame(width: piece.length * unit, height: piece.thickness * unit)
                            .rotationEffect(.degrees(piece.degrees))
                            .position(x: origin.x + piece.center.x * unit + shadow.width, y: origin.y + piece.center.y * unit + shadow.height)
                    }
                    ForEach(0..<4, id: \.self) { i in
                        let piece = pieces[i]
                        PieceShape(color: Sobremesa.ingredients[i], ink: ink,
                                   fill: progress.map { PintxoLayout.fill(progress: $0, index: i) } ?? 1,
                                   corner: min(piece.corner, piece.thickness / 2) * unit, outline: max(1, 1.8 * unit))
                            .frame(width: piece.length * unit, height: piece.thickness * unit)
                            .rotationEffect(.degrees(piece.degrees))
                            .position(x: origin.x + piece.center.x * unit, y: origin.y + piece.center.y * unit)
                    }
                }
                .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.62), value: form)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
            }
        }
        .accessibilityHidden(true)
    }

    /// One microphone level becomes four lively pieces; the order and character stay fixed.
    private func levels(at time: TimeInterval) -> [CGFloat] {
        guard case .standing(let split) = form else { return [0, 0, 0, 0] }
        let character: [CGFloat] = [0.86, 1, 0.92, 0.78]
        return (0..<4).map { i in
            let source = split && i >= 2 ? others : level
            let sway = reduceMotion ? 1 : 0.78 + 0.22 * CGFloat(sin(time * (3.1 + Double(i) * 0.7) + Double(i) * 1.9))
            return source * character[i] * sway
        }
    }

    private func wobble(at time: TimeInterval) -> [CGFloat] {
        guard form == .working, !reduceMotion else { return [0, 0, 0, 0] }
        return (0..<4).map { CGFloat(sin(time * 4.4 + Double($0) * 1.1)) * 5 }
    }
}

/// One piece: paper where not yet filled, an ingredient where filled, ink outline.
private struct PieceShape: View {
    var color: Color
    var ink: Color
    var fill: Double
    var corner: CGFloat
    var outline: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .circular)
        ZStack(alignment: .leading) {
            shape.fill(Sobremesa.paper)
            GeometryReader { proxy in
                Rectangle().fill(color).frame(width: proxy.size.width * fill)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(ink, lineWidth: outline))
    }
}

extension DictationPhase {
    /// How the Dictado tab's pintxo looks in each phase.
    var pintxoForm: PintxoForm {
        switch self {
        case .listening: .standing(split: false)
        case .starting, .finishing: .working
        default: .resting
        }
    }
}
