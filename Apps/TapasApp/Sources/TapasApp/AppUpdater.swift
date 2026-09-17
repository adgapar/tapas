import AppKit
import Sparkle
import TapasCore

@MainActor @Observable
final class UpdateModel {
    var available = false
    var canCheck = false
    var automaticallyChecks = true
    var automaticallyDownloads = true
    var waitingForRecording = false
}

@MainActor
final class AppUpdater: NSObject, SPUUpdaterDelegate {
    let model = UpdateModel()
    var isBusy: () -> Bool = { false }
    private var controller: SPUStandardUpdaterController?
    private let relaunchGate = UpdateRelaunchGate()

    func start() {
        // Command-line verification and unbundled debug runs have no update target.
        guard controller == nil, Bundle.main.bundleURL.pathExtension == "app" else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        do {
            try controller.updater.start()
            model.available = true
        } catch {
            NSLog("Tapas updater could not start: %@", error.localizedDescription)
        }
        refresh()
    }

    func refresh() {
        guard let updater = controller?.updater else { return }
        model.canCheck = updater.canCheckForUpdates && !isBusy()
        model.automaticallyChecks = updater.automaticallyChecksForUpdates
        model.automaticallyDownloads = updater.automaticallyDownloadsUpdates
        model.waitingForRecording = relaunchGate.isWaiting
        relaunchGate.resumeIfPossible(busy: isBusy())
    }

    func check() {
        guard !isBusy() else { return }
        controller?.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
        refresh()
    }

    func setAutomaticDownloads(_ enabled: Bool) {
        controller?.updater.automaticallyDownloadsUpdates = enabled
        refresh()
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        if isBusy() {
            throw NSError(domain: "work.tapas.updates", code: 1, userInfo: [NSLocalizedDescriptionKey: "Finish or recover your recording before updating tapas."])
        }
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        let postponed = relaunchGate.postponeIfNeeded(busy: isBusy(), install: installHandler)
        model.waitingForRecording = postponed
        return postponed
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        relaunchGate.cancel()
        model.waitingForRecording = false
    }
}
