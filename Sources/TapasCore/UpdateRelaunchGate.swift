/// Keeps an updater from restarting the app while capture, recognition or
/// unsaved recovery is active. The caller supplies the current recording state.
@MainActor
public final class UpdateRelaunchGate {
    private var install: (() -> Void)?
    public var isWaiting: Bool { install != nil }
    public init() {}

    public func postponeIfNeeded(busy: Bool, install: @escaping () -> Void) -> Bool {
        guard busy else { return false }
        self.install = install
        return true
    }

    public func resumeIfPossible(busy: Bool) {
        guard !busy, let install else { return }
        self.install = nil
        install()
    }

    public func cancel() { install = nil }
}
