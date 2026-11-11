import Combine
import Foundation

struct MeetingSuggestion: Equatable, Identifiable {
    let candidate: MeetingDetectionCandidate
    let title: String?
    var id: UUID { candidate.id }
}

@MainActor
final class MeetingDetectionCoordinator: ObservableObject {
    @Published private(set) var suggestion: MeetingSuggestion?
    @Published private(set) var isEnabled = false
    @Published private(set) var isAvailable = true
    @Published private(set) var calendarAccess: MeetingCalendarAccess = .notRequested
    var canSuggest: () -> Bool = { true }
    var onStart: (@MainActor (DetectedMeetingApp, String?) async -> Void)?
    private let monitor: any MeetingActivityMonitoring
    private let calendar: any MeetingCalendarProviding
    private let now: () -> Date
    private var policy = MeetingDetectionPolicy()
    private var active: [DetectedMeetingApp] = []
    private var timer: Timer?
    private var useCalendar = false
    private var suspended = false

    init(monitor: any MeetingActivityMonitoring = MeetingActivityMonitor(),
         calendar: any MeetingCalendarProviding = MeetingCalendarContext(), now: @escaping () -> Date = Date.init) {
        self.monitor = monitor; self.calendar = calendar; self.now = now
        calendarAccess = calendar.access
        monitor.onChange = { [weak self] apps, available in
            guard let self, self.isEnabled, !self.suspended else { return }
            self.active = apps; self.isAvailable = available; self.evaluate()
        }
    }

    func configure(enabled: Bool, useCalendar: Bool) {
        self.useCalendar = useCalendar
        calendarAccess = calendar.access
        if enabled != isEnabled {
            isEnabled = enabled
            if !enabled {
                monitor.stop(); timer?.invalidate(); timer = nil
                active = []; policy = MeetingDetectionPolicy(); suggestion = nil
            } else if !suspended { monitor.start() }
        }
        evaluate()
    }

    func requestCalendarAccess() async -> Bool {
        let granted = await calendar.requestAccess()
        calendarAccess = calendar.access
        return granted
    }

    func refresh() {
        calendarAccess = calendar.access
        if isEnabled && !suspended { monitor.refresh(); evaluate() }
    }

    func activityChanged(recordingMeeting: Bool = false) {
        if recordingMeeting { policy.suppressActive() }
        evaluate()
    }

    func dismiss(_ id: UUID) {
        guard suggestion?.id == id else { return }
        policy.dismiss(id); suggestion = nil; evaluate()
    }

    func start(_ id: UUID) async {
        // Re-read activity before accepting a possibly stale click.
        refresh()
        guard isEnabled, !suspended, canSuggest(), let current = suggestion, current.id == id,
              current.candidate.expiresAt > now(), active.contains(current.candidate.app) else { return }
        policy.suppressActive(); suggestion = nil; timer?.invalidate(); timer = nil
        await onStart?(current.candidate.app, current.title)
    }

    func suspend() {
        suspended = true; policy.suppressActive(); suggestion = nil
        timer?.invalidate(); timer = nil; monitor.stop()
    }

    func resume() {
        suspended = false
        if isEnabled { monitor.start() }
    }

    func stop() { configure(enabled: false, useCalendar: false) }

    private func evaluate() {
        timer?.invalidate(); timer = nil
        guard isEnabled, !suspended else { suggestion = nil; return }
        let date = now()
        let candidate = policy.update(active: isAvailable ? active : [], now: date, blocked: !canSuggest())
        if let candidate {
            let title = useCalendar ? calendar.title(for: candidate.app.kind, now: date) : nil
            let value = MeetingSuggestion(candidate: candidate, title: title)
            if suggestion != value { suggestion = value }
        } else { suggestion = nil }
        if let next = policy.nextEvaluation {
            timer = Timer.scheduledTimer(withTimeInterval: max(0.05, next.timeIntervalSince(date)), repeats: false) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            if let timer { RunLoop.main.add(timer, forMode: .common) }
        }
    }
}
