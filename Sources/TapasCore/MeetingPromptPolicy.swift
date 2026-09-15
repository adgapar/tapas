import Foundation

/// A microphone-use episode is a hint, not proof of a meeting. Decisions here
/// only offer a prompt; capture always requires a separate user action.
public struct MeetingPromptPolicy: Sendable {
    private struct Episode: Sendable {
        var since: TimeInterval
        var lastSeen: TimeInterval
        var offered = false
    }
    private var episodes: [String: Episode] = [:]
    private var previouslyActive: Set<String> = []
    private var lastPrompt: TimeInterval?
    public let debounce: TimeInterval
    public let rearmAfter: TimeInterval
    public let cooldown: TimeInterval

    public init(debounce: TimeInterval = 3, rearmAfter: TimeInterval = 60, cooldown: TimeInterval = 60) {
        self.debounce = debounce
        self.rearmAfter = rearmAfter
        self.cooldown = cooldown
    }

    /// `activeApps` is ordered by preference, normally foreground app first.
    /// Busy Dictado/setup defers a prompt; an existing Acta session consumes it.
    public mutating func update(activeApps: [String], now: TimeInterval, canPrompt: Bool, actaInProgress: Bool) -> String? {
        guard now.isFinite else { return nil }
        episodes = episodes.filter { now - $0.value.lastSeen < rearmAfter }
        let active = Set(activeApps)
        for app in active {
            var episode = episodes[app] ?? Episode(since: now, lastSeen: now)
            if !previouslyActive.contains(app) { episode.since = now }
            episode.lastSeen = now
            if actaInProgress { episode.offered = true }
            episodes[app] = episode
        }
        previouslyActive = active
        guard canPrompt, !actaInProgress, lastPrompt.map({ now - $0 >= cooldown }) ?? true else { return nil }
        guard let app = activeApps.first(where: { id in
            guard let episode = episodes[id] else { return false }
            return !episode.offered && now - episode.since >= debounce
        }) else { return nil }
        // Co-occurring microphone users belong to the same offered conversation.
        // Dismissal, timeout and acceptance all suppress repeated offers.
        for id in active { episodes[id]?.offered = true }
        lastPrompt = now
        return app
    }
}

public struct MicrophoneApp: Equatable, Sendable {
    public var pid: Int32
    public var bundleID: String
    public var name: String
    public init(pid: Int32, bundleID: String, name: String) {
        self.pid = pid; self.bundleID = bundleID; self.name = name
    }
}

public enum MicrophoneAppAttribution {
    /// Only resolve an actual owning app; never guess from the foreground app.
    /// A browser helper can have the host bundle ID plus a dotted suffix.
    public static func owner(pid: Int32, bundleID: String?, apps: [MicrophoneApp], ownPID: Int32, ownBundleID: String) -> MicrophoneApp? {
        guard pid != ownPID, bundleID != ownBundleID,
              bundleID?.hasPrefix(ownBundleID + ".") != true else { return nil }
        let eligible = apps.filter { $0.pid != ownPID && $0.bundleID != ownBundleID }
        if let exact = eligible.first(where: { $0.pid == pid }) { return exact }
        guard let bundleID else { return nil }
        return eligible.filter { bundleID == $0.bundleID || bundleID.hasPrefix($0.bundleID + ".") }
            .sorted { $0.bundleID.count > $1.bundleID.count }.first
    }
}
