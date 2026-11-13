import Foundation
import XCTest
@testable import MumlaMac

final class FocusedTextValueTests: XCTestCase {
    func testEmptyEditorDoesNotRequireAnEmptyAccessibilityRangeQuery() {
        var queried = false
        let value = FocusedTextTargetInspector.textValue(characterCount: 0) { _ in
            queried = true
            return nil
        }
        XCTAssertEqual(value, "")
        XCTAssertFalse(queried)
    }

    func testNonemptyEditorRequiresFullReadableRange() {
        var requestedRange: CFRange?
        let value = FocusedTextTargetInspector.textValue(characterCount: 9) { range in
            requestedRange = range
            return "Hej Mumla"
        }
        XCTAssertEqual(value, "Hej Mumla")
        XCTAssertEqual(requestedRange?.location, 0)
        XCTAssertEqual(requestedRange?.length, 9)
        XCTAssertNil(FocusedTextTargetInspector.textValue(characterCount: 9) { _ in nil })
    }

    func testInvalidOrOversizedRangesAreNotReadOrAssumedEmpty() {
        for count in [-1, 1_000_001] {
            var queried = false
            let value = FocusedTextTargetInspector.textValue(characterCount: count) { _ in
                queried = true
                return ""
            }
            XCTAssertNil(value)
            XCTAssertFalse(queried)
        }
    }
}
