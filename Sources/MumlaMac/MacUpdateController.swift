import AppKit
import Combine
import MumlaUI
#if MUMLA_DIRECT_UPDATES
import Sparkle
#endif

struct MacUpdateConfiguration: Equatable {
    let feedURL: URL
    let publicKey: String

    init?(info: [String: Any]) {
        guard info["MumlaDistribution"] as? String == "direct",
              let feed = info["SUFeedURL"] as? String, let url = URL(string: feed),
              url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil,
              let key = info["SUPublicEDKey"] as? String,
              Data(base64Encoded: key)?.count == 32,
              info["SURequireSignedFeed"] as? Bool == true,
              info["SUVerifyUpdateBeforeExtraction"] as? Bool == true else { return nil }
        feedURL = url
        publicKey = key
    }
}

@MainActor
final class MacUpdateController: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var isWaitingForIdle = false
    private weak var coordinator: AppCoordinator?
    private let installGate = AppUpdateInstallGate()
    private var cancellables: Set<AnyCancellable> = []
    #if MUMLA_DIRECT_UPDATES
    private var controller: SPUStandardUpdaterController?
    private var checkObservation: NSKeyValueObservation?
    #endif

    init(coordinator: AppCoordinator? = nil) {
        self.coordinator = coordinator
        super.init()
        #if MUMLA_DIRECT_UPDATES
        guard let coordinator,
              MacUpdateConfiguration(info: Bundle.main.infoDictionary ?? [:]) != nil else { return }
        installGate.isBusy = coordinator.isBusyForAppUpdate
        installGate.onCommit = { [weak coordinator] in coordinator?.setAppUpdateInstallationInProgress(true) }
        installGate.onReset = { [weak coordinator] in coordinator?.setAppUpdateInstallationInProgress(false) }
        coordinator.$isBusyForAppUpdate
            .receive(on: RunLoop.main)
            .sink { [weak self, weak coordinator] _ in
                guard let self, let coordinator else { return }
                // Re-read current activity; queued notifications may describe an earlier idle transition.
                self.installGate.isBusy = coordinator.isBusyForAppUpdate
                self.isWaitingForIdle = self.installGate.isWaitingForIdle
                self.refreshAvailability()
            }.store(in: &cancellables)
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        controller.startUpdater()
        isAvailable = true
        checkObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in self?.refreshAvailability() }
        }
        refreshAvailability()
        #endif
    }

    func checkForUpdates() {
        #if MUMLA_DIRECT_UPDATES
        guard canCheckForUpdates, coordinator?.isBusyForAppUpdate == false else { return }
        controller?.checkForUpdates(nil)
        #endif
    }

    private func refreshAvailability() {
        #if MUMLA_DIRECT_UPDATES
        canCheckForUpdates = isAvailable && controller?.updater.canCheckForUpdates == true
            && coordinator?.isBusyForAppUpdate == false && !installGate.isCommitted
        #endif
    }
}

#if MUMLA_DIRECT_UPDATES
extension MacUpdateController: SPUUpdaterDelegate {
    func allowedChannels(for updater: SPUUpdater) -> Set<String> { ["beta"] }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        coordinator?.setAppUpdateInstallationInProgress(true)
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard coordinator?.isBusyForAppUpdate == false, !installGate.isCommitted else {
            throw NSError(domain: "com.mumla.app.updates", code: 1, userInfo: [
                NSLocalizedDescriptionKey: mText("Avsluta dikteringen innan du uppdaterar.", "Finish your dictation before updating.")
            ])
        }
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        installGate.isBusy = coordinator?.isBusyForAppUpdate ?? true
        let postponed = installGate.postponeInstall(installHandler)
        isWaitingForIdle = installGate.isWaitingForIdle
        refreshAvailability()
        return postponed
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        installGate.reset()
        isWaitingForIdle = false
        refreshAvailability()
    }
}
#endif
