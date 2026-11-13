import Foundation
import XCTest
@testable import MumlaCore

final class MeetingLibraryTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func meeting(_ title: String = "Product review", time: TimeInterval = 1_800_000_000) -> MeetingRecord {
        var record = MeetingRecord(title: title, sourceName: "System audio", microphoneOnly: false,
                                   createdAt: Date(timeIntervalSince1970: time))
        record.capture = .saved; record.processing = .ready
        record.speakerNames = ["system-0": "Anna"]
        record.segments = [
            .init(id: "later", chunkID: "fixture", track: .system, start: 3600, end: 3605,
                  speaker: "system-0", text: "Sista punkten gäller återkoppling."),
            .init(id: "first", chunkID: "fixture", track: .microphone, start: 0, end: 2,
                  speaker: "microphone", text: "First point.\n\nThe delivery is ready.")]
        return record
    }

    func testSearchFindsWholeMeetingsAcrossTitleSourceSpeakerAndLateTranscript() {
        let record = meeting()
        for query in ["PRODUCT", "system audio", "Anna", "ATERKOPPLING", "review Anna sista", "  delivery  \n ready "] {
            let results = MeetingLibrary.days([record], matching: query, calendar: calendar)
            XCTAssertEqual(results.flatMap(\.meetings), [record], query)
        }
        XCTAssertTrue(MeetingLibrary.days([record], matching: "review missing", calendar: calendar).isEmpty)
        XCTAssertTrue(MeetingLibrary.days([], matching: "", calendar: calendar).isEmpty)
        var unnamed = record
        unnamed.speakerNames = [:]
        XCTAssertEqual(MeetingLibrary.days([unnamed], matching: "remote 1", calendar: calendar).first?.meetings, [unnamed])
    }

    func testDateGroupsUseCalendarDaysAndNewestFirstWithStableTieBreak() {
        let midnight = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let yesterday = midnight.addingTimeInterval(-1)
        var a = meeting("First", time: midnight.timeIntervalSince1970 + 3600)
        var b = meeting("Second", time: a.createdAt.timeIntervalSince1970)
        a.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        b.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let old = meeting("Old", time: yesterday.timeIntervalSince1970)
        let days = MeetingLibrary.days([old, b, a], matching: " \n ", calendar: calendar)
        XCTAssertEqual(days.map(\.id), [midnight, calendar.startOfDay(for: yesterday)])
        XCTAssertEqual(days[0].meetings.map(\.id), [a.id, b.id])
        XCTAssertEqual(days[1].meetings, [old])
    }

    func testPreviewIsChronologicalSingleLineAndShowsMatchingPassageWithoutChangingText() {
        var record = meeting()
        XCTAssertEqual(MeetingLibrary.preview(record, matching: ""), "First point. The delivery is ready.")
        XCTAssertEqual(MeetingLibrary.preview(record, matching: "aterkoppling"), "Sista punkten gäller återkoppling.")
        record.segments[1].text = String(repeating: "a", count: 1000)
        XCTAssertEqual(MeetingLibrary.preview(record, matching: "").count, 180)
        XCTAssertEqual(record.segments[1].text.count, 1000)
        record.segments = []
        XCTAssertEqual(MeetingLibrary.preview(record, matching: ""), "")
    }

    func testCopyAndExportsContainEveryPassageEvenWhenLibrarySearchMatchesOnlyOne() throws {
        var record = meeting()
        record.segments[0].text += String(repeating: " Full transcript.", count: 2000)
        let result = try XCTUnwrap(MeetingLibrary.days([record], matching: "delivery", calendar: calendar).first?.meetings.first)
        XCTAssertEqual(result, record)
        let text = result.transcript()
        XCTAssertTrue(text.contains("First point."))
        XCTAssertTrue(text.contains("[1:00:00] Anna:"))
        XCTAssertTrue(text.hasSuffix(String(repeating: " Full transcript.", count: 2000)))
        XCTAssertEqual(String(decoding: try result.export(.text), as: UTF8.self), text)
        XCTAssertEqual(String(decoding: try result.export(.markdown), as: UTF8.self), result.markdown)
        XCTAssertEqual(try result.export(.json), try result.exportJSON())
    }

    func testGroupingRespectsLocalTimezoneAroundMidnight() {
        var local = calendar
        local.timeZone = TimeZone(secondsFromGMT: 3600)!
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let before = meeting(time: day.timeIntervalSince1970 - 1800)
        let after = meeting(time: day.timeIntervalSince1970 + 1800)
        XCTAssertEqual(MeetingLibrary.days([before, after], matching: "", calendar: local).count, 1)
        XCTAssertEqual(MeetingLibrary.days([before, after], matching: "", calendar: calendar).count, 2)
    }
}
