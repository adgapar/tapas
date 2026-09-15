import Foundation
import CoreGraphics

/// Presentation timing is independent of capture and delivery. Showing a receipt never delays a take.
public struct DictadoPresentation: Sendable {
    private var previousPhase: DictationPhase = .idle
    private var wasSuppressed = false
    private var receiptUntil: TimeInterval?

    public init() {}

    public mutating func isVisible(for snapshot: OverlaySnapshot, suppressed: Bool, now: TimeInterval) -> Bool {
        if snapshot.phase != previousPhase {
            receiptUntil = snapshot.phase == .delivered && previousPhase != .idle && !wasSuppressed && !suppressed
                ? now + 1.6 : nil
        }
        // Opening setup or the plate consumes a receipt; closing it must not resurrect one.
        if suppressed { receiptUntil = nil }
        previousPhase = snapshot.phase
        wasSuppressed = suppressed
        guard !suppressed else { return false }
        switch snapshot.phase {
        case .idle: return false
        case .delivered: return receiptUntil.map { now < $0 } ?? false
        default: return snapshot.isVisible
        }
    }
}

/// AppKit coordinates (origin at the bottom left). Keep every surface below both menu bar and camera.
public enum DictadoPlacement {
    public static func frame(size: CGSize, screen: CGRect, visible: CGRect, safeTopInset: CGFloat, offset: CGFloat = 0) -> CGRect {
        let width = min(size.width, visible.width)
        let height = min(size.height, visible.height)
        let top = min(visible.maxY, screen.maxY - safeTopInset) - 6 - offset
        return CGRect(x: visible.midX - width / 2, y: max(visible.minY, top - height), width: width, height: height)
    }
}
