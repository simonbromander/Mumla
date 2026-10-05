import Foundation

@MainActor
final class AppUpdateInstallGate {
    var isBusy = false {
        didSet { resumeIfIdle() }
    }
    private(set) var isCommitted = false
    private(set) var isWaitingForIdle = false
    var onCommit: (() -> Void)?
    var onReset: (() -> Void)?
    private var pendingInstall: (() -> Void)?

    func postponeInstall(_ handler: @escaping () -> Void) -> Bool {
        isCommitted = true
        onCommit?()
        guard isBusy else { return false }
        pendingInstall = handler
        isWaitingForIdle = true
        return true
    }

    func reset() {
        pendingInstall = nil
        isWaitingForIdle = false
        isCommitted = false
        onReset?()
    }

    private func resumeIfIdle() {
        guard !isBusy, let handler = pendingInstall else { return }
        pendingInstall = nil
        isWaitingForIdle = false
        handler()
    }
}
