import SwiftUI
import TapasCore

/// Skill state for each assistant. Nothing is installed until the person chooses Install.
@MainActor @Observable
final class AssistantSetupModel {
    enum State: Equatable {
        case absent, missing, installed, update
        case attention(String)
    }

    /// The assistant the last action applied to.
    var host: AssistantHost = .codex
    /// Status text for `host`, as reported by AssistantSkill.
    var status = "Not installed"
    var statuses: [AssistantHost: String] = [:]
    var present: Set<AssistantHost> = Set(AssistantHost.allCases)
    var message: String?

    func state(for host: AssistantHost) -> State {
        let status = statuses[host] ?? (host == self.host ? self.status : "Not installed")
        switch status {
        case "Installed": return .installed
        case "Update available": return .update
        case "Not installed": return present.contains(host) ? .missing : .absent
        default: return .attention(status)
        }
    }

    /// Re-read every assistant's skill and whether the assistant is on this Mac.
    func refresh(skill: AssistantSkill = AssistantSkill()) {
        for host in AssistantHost.allCases { statuses[host] = skill.status(for: host) }
        present = Set(AssistantHost.allCases.filter { AssistantPresence.isPresent($0) })
        status = statuses[host] ?? status
    }

    /// Actions are "verb" or "verb:host". Returns the verb and selects the host.
    func parse(_ action: String) -> String {
        let parts = action.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2, let named = AssistantHost(rawValue: parts[1]) { host = named }
        return parts.first ?? action
    }
}
