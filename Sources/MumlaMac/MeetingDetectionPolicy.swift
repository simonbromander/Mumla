import Foundation

enum MeetingAppKind: String, Sendable {
    case slack, teams

    static func identify(_ bundleID: String) -> Self? {
        switch bundleID {
        case "com.tinyspeck.slackmacgap": .slack
        case "com.microsoft.teams", "com.microsoft.teams2": .teams
        default: nil
        }
    }

    var name: String { self == .slack ? "Slack" : "Microsoft Teams" }

    func matchesMeetingURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        let domains = self == .slack ? ["slack.com"] : ["teams.microsoft.com", "teams.live.com", "teams.cloud.microsoft"]
        return domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

struct DetectedMeetingApp: Equatable, Sendable, Identifiable {
    let id: Int32
    let bundleID: String
    let kind: MeetingAppKind
}

struct MeetingAudioProcessState {
    let pid: Int32
    let bundleID: String
    let inputActive: Bool

    func belongs(to app: DetectedMeetingApp) -> Bool {
        pid == app.id || bundleID == app.bundleID || bundleID.hasPrefix(app.bundleID + ".")
    }
}

struct MeetingDetectionCandidate: Equatable, Sendable, Identifiable {
    let id: UUID
    let app: DetectedMeetingApp
    let expiresAt: Date
}

/// Microphone activity is a hint, not proof of a call. It must never start capture.
struct MeetingDetectionPolicy {
    static let debounce: TimeInterval = 2
    static let rearm: TimeInterval = 30
    static let promptLifetime: TimeInterval = 60
    private struct Session {
        let id = UUID()
        var firstSeen: Date
        var absentSince: Date?
        var presentedAt: Date?
        var handled = false
    }
    private var sessions: [Int32: Session] = [:]
    private(set) var nextEvaluation: Date?

    mutating func update(active: [DetectedMeetingApp], now: Date, blocked: Bool) -> MeetingDetectionCandidate? {
        nextEvaluation = nil
        let activeIDs = Set(active.map(\.id))
        for id in Array(sessions.keys) where !activeIDs.contains(id) {
            if sessions[id]?.absentSince == nil {
                sessions[id]?.absentSince = now
                if sessions[id]?.presentedAt != nil { sessions[id]?.handled = true }
            }
            if let absent = sessions[id]?.absentSince, now.timeIntervalSince(absent) >= Self.rearm {
                sessions.removeValue(forKey: id)
            } else if let absent = sessions[id]?.absentSince {
                schedule(absent.addingTimeInterval(Self.rearm))
            }
        }
        var result: MeetingDetectionCandidate?
        for app in active.sorted(by: { $0.id < $1.id }) {
            var session = sessions[app.id] ?? Session(firstSeen: now)
            if let absent = session.absentSince {
                if now.timeIntervalSince(absent) >= Self.rearm { session = Session(firstSeen: now) }
                else { session.firstSeen = now }
                session.absentSince = nil
            }
            if let presented = session.presentedAt, now.timeIntervalSince(presented) >= Self.promptLifetime { session.handled = true }
            if !session.handled && !blocked {
                let ready = session.firstSeen.addingTimeInterval(Self.debounce)
                if now < ready { schedule(ready) }
                else if result == nil {
                    if session.presentedAt == nil { session.presentedAt = now }
                    let expires = session.presentedAt!.addingTimeInterval(Self.promptLifetime)
                    schedule(expires)
                    result = MeetingDetectionCandidate(id: session.id, app: app, expiresAt: expires)
                }
            }
            sessions[app.id] = session
        }
        return result
    }

    mutating func dismiss(_ id: UUID) {
        for key in Array(sessions.keys) where sessions[key]?.id == id { sessions[key]?.handled = true }
    }

    mutating func suppressActive() {
        for key in Array(sessions.keys) { sessions[key]?.handled = true }
    }

    private mutating func schedule(_ date: Date) { nextEvaluation = min(nextEvaluation ?? date, date) }
}

struct MeetingCalendarEvent: Equatable {
    let title: String
    let start: Date
    let end: Date
    let urls: [URL]
    let excluded: Bool

    static func matchingTitle(in events: [Self], app: MeetingAppKind, now: Date) -> String? {
        events.filter {
            !$0.excluded && $0.start <= now.addingTimeInterval(5 * 60) && $0.end > now &&
            $0.urls.contains(where: app.matchesMeetingURL) && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.min { abs($0.start.timeIntervalSince(now)) < abs($1.start.timeIntervalSince(now)) }
            .map { String($0.title.prefix(200)) }
    }
}
