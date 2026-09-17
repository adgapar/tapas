import Foundation

/// Tracks only a recording explicitly started from a meeting suggestion.
public struct MeetingEndPolicy: Sendable {
    public let app: MicrophoneApp
    public let gracePeriod: TimeInterval
    private var inactiveSince: TimeInterval?
    private var lastUpdate: TimeInterval?

    public init(app: MicrophoneApp, gracePeriod: TimeInterval = 30) {
        self.app = app
        self.gracePeriod = gracePeriod
    }

    /// Unknown snapshots and polling gaps (including sleep) cannot prove inactivity.
    public mutating func shouldFinish(activeApps: [MicrophoneApp]?, now: TimeInterval) -> Bool {
        guard now.isFinite else { inactiveSince = nil; lastUpdate = nil; return false }
        if let lastUpdate, now < lastUpdate || now - lastUpdate > 5 { inactiveSince = nil }
        lastUpdate = now
        guard let activeApps else { inactiveSince = nil; return false }
        if activeApps.contains(where: { $0.pid == app.pid && $0.bundleID == app.bundleID }) {
            inactiveSince = nil
            return false
        }
        if inactiveSince == nil { inactiveSince = now }
        return now - inactiveSince! >= gracePeriod
    }
}
