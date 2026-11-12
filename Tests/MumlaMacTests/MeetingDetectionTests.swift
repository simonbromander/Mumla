import Foundation
import XCTest
@testable import MumlaMac

final class MeetingDetectionPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100_000)
    private let slack = DetectedMeetingApp(id: 123, bundleID: "com.tinyspeck.slackmacgap", kind: .slack)
    private let teams = DetectedMeetingApp(id: 456, bundleID: "com.microsoft.teams2", kind: .teams)

    func testOnlyKnownAppsAndTheirOwnHelperProcessesMatch() {
        XCTAssertEqual(MeetingAppKind.identify(slack.bundleID), .slack)
        XCTAssertEqual(MeetingAppKind.identify("com.microsoft.teams"), .teams)
        XCTAssertEqual(MeetingAppKind.identify(teams.bundleID), .teams)
        XCTAssertNil(MeetingAppKind.identify("com.apple.Safari"))
        XCTAssertNil(MeetingAppKind.identify("com.microsoft.teams2.unrelated"))
        XCTAssertTrue(MeetingAudioProcessState(pid: 2, bundleID: slack.bundleID + ".helper", inputActive: true).belongs(to: slack))
        XCTAssertTrue(MeetingAudioProcessState(pid: slack.id, bundleID: "", inputActive: true).belongs(to: slack))
        XCTAssertFalse(MeetingAudioProcessState(pid: 2, bundleID: slack.bundleID + "fake", inputActive: true).belongs(to: slack))
        XCTAssertFalse(MeetingAudioProcessState(pid: 2, bundleID: teams.bundleID, inputActive: true).belongs(to: slack))
    }

    func testNoActivityAndShortInputUseNeverSuggest() {
        var policy = MeetingDetectionPolicy()
        XCTAssertNil(policy.update(active: [], now: now, blocked: false))
        XCTAssertNil(policy.nextEvaluation)
        XCTAssertNil(policy.update(active: [slack], now: now, blocked: false))
        XCTAssertEqual(policy.nextEvaluation, now.addingTimeInterval(2))
        XCTAssertNil(policy.update(active: [], now: now.addingTimeInterval(1), blocked: false))
        XCTAssertNil(policy.update(active: [], now: now.addingTimeInterval(4), blocked: false))
    }

    func testDismissalSurvivesMuteGapsButRearmsForNextCall() throws {
        var policy = MeetingDetectionPolicy()
        _ = policy.update(active: [slack], now: now, blocked: false)
        let first = try XCTUnwrap(policy.update(active: [slack], now: now.addingTimeInterval(2), blocked: false))
        policy.dismiss(first.id)
        XCTAssertNil(policy.update(active: [slack], now: now.addingTimeInterval(3), blocked: false))
        XCTAssertNil(policy.update(active: [], now: now.addingTimeInterval(4), blocked: false))
        XCTAssertNil(policy.update(active: [slack], now: now.addingTimeInterval(20), blocked: false))
        _ = policy.update(active: [], now: now.addingTimeInterval(21), blocked: false)
        _ = policy.update(active: [slack], now: now.addingTimeInterval(51), blocked: false)
        let second = try XCTUnwrap(policy.update(active: [slack], now: now.addingTimeInterval(53), blocked: false))
        XCTAssertNotEqual(first.id, second.id)
    }

    func testPromptExpiresWithoutReappearingDuringTheSameCall() throws {
        var policy = MeetingDetectionPolicy()
        _ = policy.update(active: [slack], now: now, blocked: false)
        let prompt = try XCTUnwrap(policy.update(active: [slack], now: now.addingTimeInterval(2), blocked: false))
        XCTAssertEqual(prompt.expiresAt, now.addingTimeInterval(62))
        XCTAssertNil(policy.update(active: [slack], now: now.addingTimeInterval(62), blocked: false))
        XCTAssertNil(policy.update(active: [slack], now: now.addingTimeInterval(600), blocked: false))
        XCTAssertNil(policy.nextEvaluation)
    }

    func testBusyDefersAndManualRecordingSuppresses() throws {
        var policy = MeetingDetectionPolicy()
        XCTAssertNil(policy.update(active: [slack], now: now, blocked: true))
        XCTAssertNil(policy.nextEvaluation)
        XCTAssertNotNil(policy.update(active: [slack], now: now.addingTimeInterval(3), blocked: false))
        policy.suppressActive()
        XCTAssertNil(policy.update(active: [slack], now: now.addingTimeInterval(4), blocked: false))
    }

    func testEndedCallHidesPromptAndSecondAppHasIndependentSession() throws {
        var policy = MeetingDetectionPolicy()
        _ = policy.update(active: [slack], now: now, blocked: false)
        _ = try XCTUnwrap(policy.update(active: [slack], now: now.addingTimeInterval(2), blocked: false))
        XCTAssertNil(policy.update(active: [], now: now.addingTimeInterval(3), blocked: false))
        XCTAssertNil(policy.update(active: [slack], now: now.addingTimeInterval(4), blocked: false))
        _ = policy.update(active: [slack, teams], now: now.addingTimeInterval(5), blocked: false)
        XCTAssertEqual(policy.update(active: [slack, teams], now: now.addingTimeInterval(7), blocked: false)?.app, teams)
    }

    func testCalendarOnlyMatchesNearbyNonExcludedProviderLinks() {
        let matching = event("Synthetic team check-in", start: -60, end: 1800, url: "https://teams.microsoft.com/l/meetup-join/test")
        let unrelated = event("Wrong provider", start: 0, end: 1800, url: "https://app.slack.com/huddle/test")
        let events = [matching, unrelated,
            event("Ended", start: -600, end: -1, url: matching.urls[0].absoluteString),
            event("Tomorrow", start: 86400, end: 90000, url: matching.urls[0].absoluteString),
            event("Declined or all day", start: 0, end: 1800, url: matching.urls[0].absoluteString, excluded: true)]
        XCTAssertEqual(MeetingCalendarEvent.matchingTitle(in: events, app: .teams, now: now), matching.title)
        XCTAssertEqual(MeetingCalendarEvent.matchingTitle(in: events, app: .slack, now: now), unrelated.title)
        XCTAssertNil(MeetingCalendarEvent.matchingTitle(in: [unrelated], app: .teams, now: now))
        XCTAssertFalse(MeetingAppKind.teams.matchesMeetingURL(URL(string: "https://teams.microsoft.com.attacker.invalid/test")!))
        XCTAssertFalse(MeetingAppKind.teams.matchesMeetingURL(URL(string: "http://teams.microsoft.com/test")!))
        XCTAssertTrue(MeetingAppKind.teams.matchesMeetingURL(URL(string: "https://teams.cloud.microsoft/meet/test")!))
    }

    private func event(_ title: String, start: Double, end: Double, url: String, excluded: Bool = false) -> MeetingCalendarEvent {
        .init(title: title, start: now.addingTimeInterval(start), end: now.addingTimeInterval(end), urls: [URL(string: url)!], excluded: excluded)
    }
}

@MainActor
private final class DetectionMonitorFixture: MeetingActivityMonitoring {
    var onChange: (([DetectedMeetingApp], Bool) -> Void)?
    var active: [DetectedMeetingApp] = []
    var available = true
    var starts = 0
    var stops = 0
    func start() { starts += 1; refresh() }
    func refresh() { onChange?(active, available) }
    func stop() { stops += 1 }
}

@MainActor
private final class CalendarContextFixture: MeetingCalendarProviding {
    var access: MeetingCalendarAccess = .notRequested
    var requests = 0
    var reads = 0
    var grants = false
    func requestAccess() async -> Bool { requests += 1; access = grants ? .allowed : .denied; return grants }
    func title(for app: MeetingAppKind, now: Date) -> String? { reads += 1; return access == .allowed ? "Synthetic meeting" : nil }
}

@MainActor
final class MeetingDetectionCoordinatorTests: XCTestCase {
    private let slack = DetectedMeetingApp(id: 123, bundleID: "com.tinyspeck.slackmacgap", kind: .slack)

    func testNativeProcessObservationStartsAndStopsWithoutCreatingCapture() throws {
        guard #available(macOS 14.2, *) else { throw XCTSkip("Core Audio process observation needs macOS 14.2") }
        let monitor = MeetingActivityMonitor()
        defer { monitor.stop() }
        var delivered = false
        monitor.onChange = { _, available in delivered = available }
        monitor.start()
        XCTAssertTrue(delivered)
        XCTAssertTrue(monitor.isObserving)
        monitor.stop()
        XCTAssertFalse(monitor.isObserving)
    }

    func testDisabledDoesNotObserveRequestCalendarOrStartAnything() async {
        let monitor = DetectionMonitorFixture(), calendar = CalendarContextFixture()
        let model = MeetingDetectionCoordinator(monitor: monitor, calendar: calendar)
        var starts = 0; model.onStart = { _, _ in starts += 1 }
        model.configure(enabled: false, useCalendar: false)
        monitor.active = [slack]; monitor.refresh()
        await model.start(UUID())
        XCTAssertEqual(monitor.starts, 0); XCTAssertEqual(calendar.requests, 0); XCTAssertEqual(calendar.reads, 0)
        XCTAssertEqual(starts, 0); XCTAssertNil(model.suggestion)
    }

    func testOnlyExplicitStartCapturesOnceWithCorrectSourceAndOptionalTitle() async throws {
        let monitor = DetectionMonitorFixture(), calendar = CalendarContextFixture()
        calendar.access = .allowed
        var now = Date(); monitor.active = [slack]
        let model = MeetingDetectionCoordinator(monitor: monitor, calendar: calendar, now: { now })
        defer { model.stop() }
        var sources: [DetectedMeetingApp] = []; var titles: [String?] = []
        model.onStart = { source, title in sources.append(source); titles.append(title) }
        model.configure(enabled: true, useCalendar: true)
        now.addTimeInterval(2); model.refresh()
        let suggestion = try XCTUnwrap(model.suggestion)
        XCTAssertEqual(sources.count, 0); XCTAssertEqual(calendar.requests, 0)
        await model.start(suggestion.id)
        await model.start(suggestion.id)
        XCTAssertEqual(sources, [slack]); XCTAssertEqual(titles, ["Synthetic meeting"])
        XCTAssertNil(model.suggestion)
    }

    func testStaleEndedExpiredAndDisabledPromptsCannotStart() async throws {
        for transition in ["ended", "expired", "disabled", "unavailable", "busy", "sleep"] {
            let monitor = DetectionMonitorFixture(), calendar = CalendarContextFixture()
            var now = Date(); monitor.active = [slack]
            let model = MeetingDetectionCoordinator(monitor: monitor, calendar: calendar, now: { now })
            var starts = 0; model.onStart = { _, _ in starts += 1 }
            model.configure(enabled: true, useCalendar: false)
            now.addTimeInterval(2); model.refresh()
            let suggestion = try XCTUnwrap(model.suggestion)
            switch transition {
            case "ended": monitor.active = []
            case "expired": now.addTimeInterval(60)
            case "disabled": model.configure(enabled: false, useCalendar: false)
            case "unavailable": monitor.available = false
            case "busy": model.canSuggest = { false }
            default: model.suspend()
            }
            await model.start(suggestion.id)
            XCTAssertEqual(starts, 0, transition); XCTAssertNil(model.suggestion, transition)
            XCTAssertEqual(calendar.reads, 0)
            model.stop()
        }
    }

    func testDismissAndSleepDoNotRepromptOnSameCall() throws {
        let monitor = DetectionMonitorFixture(), calendar = CalendarContextFixture()
        var now = Date(); monitor.active = [slack]
        let model = MeetingDetectionCoordinator(monitor: monitor, calendar: calendar, now: { now })
        defer { model.stop() }
        model.configure(enabled: true, useCalendar: false)
        now.addTimeInterval(2); model.refresh()
        model.dismiss(try XCTUnwrap(model.suggestion).id)
        model.suspend(); now.addTimeInterval(120); model.resume()
        XCTAssertNil(model.suggestion); XCTAssertEqual(monitor.starts, 2)
    }

    func testCalendarPermissionIsSeparateAndDenialStillAllowsCallSuggestion() async throws {
        let monitor = DetectionMonitorFixture(), calendar = CalendarContextFixture()
        var now = Date(); monitor.active = [slack]
        let model = MeetingDetectionCoordinator(monitor: monitor, calendar: calendar, now: { now })
        defer { model.stop() }
        model.configure(enabled: true, useCalendar: false)
        let granted = await model.requestCalendarAccess()
        XCTAssertFalse(granted); XCTAssertEqual(model.calendarAccess, .denied)
        now.addTimeInterval(2); model.refresh()
        XCTAssertNotNil(model.suggestion); XCTAssertNil(model.suggestion?.title)
        XCTAssertEqual(calendar.reads, 0); XCTAssertEqual(calendar.requests, 1)
    }

    func testCalendarLinkExtractionUsesStructuredLinkDetection() {
        let urls = MeetingCalendarContext.meetingURLs(url: nil, location: "https://teams.microsoft.com/l/test", notes: "Join at https://app.slack.com/huddle/example.")
        XCTAssertEqual(urls.count, 2)
        XCTAssertTrue(urls.contains { MeetingAppKind.teams.matchesMeetingURL($0) })
        XCTAssertTrue(urls.contains { MeetingAppKind.slack.matchesMeetingURL($0) })
    }
}
