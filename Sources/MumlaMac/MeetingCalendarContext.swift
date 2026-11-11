import EventKit
import Foundation

enum MeetingCalendarAccess { case notRequested, allowed, denied, restricted }

@MainActor
protocol MeetingCalendarProviding: AnyObject {
    var access: MeetingCalendarAccess { get }
    func requestAccess() async -> Bool
    func title(for app: MeetingAppKind, now: Date) -> String?
}

@MainActor
final class MeetingCalendarContext: MeetingCalendarProviding {
    private var store: EKEventStore?

    var access: MeetingCalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .allowed
        case .notDetermined, .writeOnly: .notRequested
        case .restricted: .restricted
        default: .denied
        }
    }

    func requestAccess() async -> Bool {
        let store = store ?? EKEventStore()
        self.store = store
        return (try? await store.requestFullAccessToEvents()) == true
    }

    func title(for app: MeetingAppKind, now: Date) -> String? {
        guard access == .allowed else { return nil }
        let store = store ?? EKEventStore()
        self.store = store
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-86400),
                                                 end: now.addingTimeInterval(5 * 60), calendars: nil)
        let events = store.events(matching: predicate).map { event in
            let declined = event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } == true
            return MeetingCalendarEvent(title: event.title ?? "", start: event.startDate, end: event.endDate,
                urls: Self.meetingURLs(url: event.url, location: event.location, notes: event.notes),
                excluded: event.isAllDay || event.status == .canceled || declined)
        }
        return MeetingCalendarEvent.matchingTitle(in: events, app: app, now: now)
    }

    static func meetingURLs(url: URL?, location: String?, notes: String?) -> [URL] {
        let text = [location, notes].compactMap { $0 }.joined(separator: "\n")
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let links = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url) ?? []
        return (url.map { [$0] } ?? []) + links
    }
}
