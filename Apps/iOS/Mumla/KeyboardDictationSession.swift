@preconcurrency import ActivityKit
import AVFoundation
import MumlaCore
import MumlaUI
import UIKit

@MainActor
final class KeyboardDictationSession {
    private let capture = KeyboardAudioCapture()
    private let store: KeyboardSessionStore
    private let transcribe: @MainActor (URL) async throws -> DictationRecord
    private let changed: @MainActor (KeyboardSessionSnapshot) -> Void
    private let canRetry: @MainActor () -> Bool
    private var snapshot = KeyboardSessionSnapshot()
    private var loop: Task<Void, Never>?
    private var processing: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var documentID: UUID?
    private var activity: Activity<MumlaKeyboardActivityAttributes>?
    private var activityTask: Task<Void, Never>?
    private var endAfterProcessing = false
    private var pendingURL: URL?
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    private var lastActivityUpdate = Date.distantPast

    init(store: KeyboardSessionStore, transcribe: @escaping @MainActor (URL) async throws -> DictationRecord,
         canRetry: @escaping @MainActor () -> Bool, changed: @escaping @MainActor (KeyboardSessionSnapshot) -> Void) {
        self.store = store; self.transcribe = transcribe; self.changed = changed; self.canRetry = canRetry
    }

    func start() async throws {
        guard snapshot.sessionID == nil else { return }
        snapshot = .init(); snapshot.sessionID = UUID(); snapshot.phase = .preparing
        snapshot.expiresAt = Date().addingTimeInterval(15 * 60)
        do {
            try store.clearResult(); try store.pruneClaims()
            publish()
            guard snapshot.sessionID != nil else { throw CocoaError(.fileWriteUnknown) }
            try capture.startSession()
            snapshot.phase = .ready; publish()
            guard snapshot.sessionID != nil else { throw CocoaError(.fileWriteUnknown) }
        } catch { tearDown(); throw error }
        startActivity()
        let center = NotificationCenter.default
        for name in [AVAudioSession.interruptionNotification, UIApplication.protectedDataWillBecomeUnavailableNotification,
                     AVAudioSession.routeChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if notification.name == AVAudioSession.interruptionNotification,
                   let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                   AVAudioSession.InterruptionType(rawValue: raw) != .began { return }
                if notification.name == AVAudioSession.routeChangeNotification,
                   let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                   AVAudioSession.RouteChangeReason(rawValue: raw) == .categoryChange { return }
                Task { @MainActor [weak self] in self?.end() }
            })
        }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            }
        }
    }

    func end() {
        guard snapshot.sessionID != nil else { return }
        if snapshot.phase == .transcribing { endAfterProcessing = true; releaseMicrophone(); return }
        if snapshot.phase == .recording {
            endAfterProcessing = true; finish()
            if snapshot.phase != .transcribing { tearDown() } else { releaseMicrophone() }
            return
        }
        tearDown()
    }

    private func tearDown() {
        loop?.cancel(); loop = nil
        capture.endSession()
        observers.forEach(NotificationCenter.default.removeObserver); observers.removeAll()
        snapshot = .init(); snapshot.heartbeat = Date()
        try? store.write(snapshot); changed(snapshot)
        try? store.clearResult()
        if let activity {
            let content = ActivityContent(state: activity.content.state, staleDate: nil)
            Task { await activity.end(content, dismissalPolicy: .immediate) }
        }
        activity = nil; activityTask?.cancel(); activityTask = nil
        endAfterProcessing = false; documentID = nil; pendingURL = nil
        if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask); backgroundTask = .invalid }
    }

    private func releaseMicrophone() {
        if backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finish Mumla keyboard clip") { [weak self] in
                Task { @MainActor [weak self] in self?.processing?.cancel(); self?.tearDown() }
            }
        }
        capture.endSession()
    }

    private func tick() {
        guard snapshot.sessionID != nil else { return }
        let now = Date()
        if now >= snapshot.expiresAt { end() }
        guard snapshot.sessionID != nil else { return }
        if snapshot.phase == .recording, let start = snapshot.recordingStartedAt,
           now.timeIntervalSince(start) >= 600 { finish() }
        if !capture.isRunning && snapshot.phase != .transcribing { end(); return }
        if let command = try? store.command(), snapshot.accepts(command, at: now) { handle(command) }
        publish()
        if now.timeIntervalSince(lastActivityUpdate) >= 5 { updateActivity() }
    }

    private func handle(_ command: KeyboardSessionCommand) {
        snapshot.acknowledgedCommandID = command.id
        switch command.action {
        case .start:
            do {
                try capture.startClip()
                snapshot.phase = .recording; snapshot.recordingStartedAt = Date()
                snapshot.requestID = command.id; snapshot.resultID = nil; snapshot.error = nil
                snapshot.canRetry = false
                documentID = command.documentID
                MumlaFeedback.recordStart()
            } catch { fail(error) }
        case .stop: finish()
        case .cancel:
            capture.cancelClip(); snapshot.phase = .ready; snapshot.recordingStartedAt = nil
            snapshot.requestID = nil; snapshot.error = nil; documentID = nil
        case .retry:
            if let pendingURL { process(pendingURL) }
        case .consume:
            try? store.clearResult(); snapshot.resultID = nil; snapshot.requestID = nil
            snapshot.phase = .ready; snapshot.recordingStartedAt = nil
        case .end: end()
        }
        updateActivity()
    }

    private func finish() {
        guard snapshot.phase == .recording else { return }
        do { let url = try capture.stopClip(); pendingURL = url; process(url) }
        catch {
            if let failure = error as? KeyboardCaptureFailure { pendingURL = failure.url; fail(failure.underlyingError) }
            else { fail(error) }
        }
        MumlaFeedback.recordStop()
    }

    private func process(_ url: URL) {
        guard let sessionID = snapshot.sessionID, let requestID = snapshot.requestID else { return }
        snapshot.phase = .transcribing; snapshot.error = nil; publish(); updateActivity()
        processing = Task { [weak self] in
            guard let self else { return }
            do {
                let record = try await self.transcribe(url)
                guard self.snapshot.sessionID == sessionID else { return }
                let result = KeyboardSessionResult(id: record.id, sessionID: sessionID, requestID: requestID,
                                                    documentID: self.documentID, text: record.text)
                try self.store.publish(result)
                self.snapshot.phase = .result; self.snapshot.resultID = result.id
                self.pendingURL = nil
            } catch {
                if self.snapshot.sessionID == sessionID { self.fail(error) }
            }
            self.processing = nil
            self.publish(); self.updateActivity()
            if self.endAfterProcessing { self.endAfterProcessing = false; self.end() }
        }
    }

    private func fail(_ error: Error) {
        snapshot.phase = .failed; snapshot.error = error.localizedDescription
        snapshot.canRetry = canRetry() || pendingURL.map { FileManager.default.fileExists(atPath: $0.path) } == true
        publish(); updateActivity()
    }

    private func publish() {
        snapshot.heartbeat = Date()
        snapshot.inputLevel = snapshot.phase == .recording ? capture.inputLevel : 0
        snapshot.appearance = MumlaAppearance.stored().rawValue
        snapshot.hapticsEnabled = UserDefaults.standard.object(forKey: MumlaFeedback.preferenceKey) as? Bool ?? true
        do { try store.write(snapshot) }
        catch {
            // A locked or unavailable shared container must not keep a microphone session alive.
            if snapshot.phase != .inactive { tearDown() }
        }
        changed(snapshot)
    }

    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, let id = snapshot.sessionID else { return }
        let content = activityContent()
        do {
            activity = try Activity.request(attributes: MumlaKeyboardActivityAttributes(sessionID: id), content: content, pushType: nil)
            activityTask = Task { [weak self, activity] in
                guard let activity else { return }
                for await state in activity.activityStateUpdates {
                    if state == .dismissed || state == .ended { self?.end(); return }
                }
            }
        } catch { /* The keyboard session also has the system microphone indicator. */ }
    }
    private func updateActivity() {
        guard let activity else { return }
        lastActivityUpdate = Date()
        let content = activityContent()
        Task { await activity.update(content) }
    }
    private func activityContent() -> ActivityContent<MumlaKeyboardActivityAttributes.ContentState> {
        ActivityContent(state: .init(phase: snapshot.phase.rawValue, recordingStartedAt: snapshot.recordingStartedAt,
                                     expiresAt: snapshot.expiresAt), staleDate: min(snapshot.expiresAt, Date().addingTimeInterval(15)))
    }
}
