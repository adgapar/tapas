import Foundation

struct ModelPreparationStatus: Equatable, Sendable {
    enum Phase: Sendable { case checking, downloading, preparing }
    var model = "voice models"
    var phase: Phase = .checking
    var fraction: Double?
    var startedAt = Date()

    var title: String {
        switch phase {
        case .checking: "Checking \(model) files…"
        case .downloading: "Downloading \(model)…"
        case .preparing: "Preparing \(model) for this Mac…"
        }
    }

    var detail: String {
        if phase != .preparing {
            return "Keep tapas open and stay connected. Downloaded files are kept if you need to retry."
        }
        return "macOS is getting this model ready for your Mac. First-time preparation can take several minutes; no percentage is available for this step. Keep tapas open."
    }
}
