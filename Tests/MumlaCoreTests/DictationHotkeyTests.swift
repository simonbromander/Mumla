import XCTest
@testable import MumlaCore

final class DictationHotkeyTests: XCTestCase {
    func testRemainingDelayExistsOnlyForAnEligiblePendingHold() throws {
        var gesture = DictationHotkeyGesture()
        XCTAssertNil(gesture.remainingHoldDelay(at: 0))
        _ = gesture.press(at: 0, eligible: true)
        XCTAssertEqual(try XCTUnwrap(gesture.remainingHoldDelay(at: 0.249)), 0.001, accuracy: 0.00001)
        _ = gesture.tick(at: 0.25)
        XCTAssertNil(gesture.remainingHoldDelay(at: 0.25))
        _ = gesture.reset()
        _ = gesture.press(at: 1, eligible: false)
        XCTAssertNil(gesture.remainingHoldDelay(at: 1))
    }

    func testHoldStartsAtThresholdAndEndsExactlyOnce() {
        var gesture = DictationHotkeyGesture()
        XCTAssertEqual(gesture.press(at: 0, eligible: true), [])
        XCTAssertEqual(gesture.tick(at: 0.249), [])
        XCTAssertEqual(gesture.tick(at: 0.25), [.startHold])
        XCTAssertEqual(gesture.tick(at: 0.5), [])
        XCTAssertEqual(gesture.release(at: 1), [.endHold])
        XCTAssertEqual(gesture.release(at: 1.1), [])
    }

    func testDoubleTapDoesNotAlsoStartOrEndAHold() {
        var gesture = DictationHotkeyGesture()
        _ = gesture.press(at: 0, eligible: true)
        XCTAssertEqual(gesture.release(at: 0.1), [.tap])
        XCTAssertEqual(gesture.press(at: 0.3, eligible: true), [.doubleTap])
        XCTAssertEqual(gesture.tick(at: 0.6), [])
        XCTAssertEqual(gesture.release(at: 0.7), [])
    }

    func testSeparatedTapsDoNotStartHandsFree() {
        var gesture = DictationHotkeyGesture()
        _ = gesture.press(at: 0, eligible: true)
        _ = gesture.release(at: 0.1)
        XCTAssertEqual(gesture.press(at: 0.46, eligible: true), [])
        XCTAssertEqual(gesture.release(at: 0.5), [.tap])
    }

    func testShortcutBeforeThresholdNeverRecordsOrInserts() {
        var gesture = DictationHotkeyGesture()
        _ = gesture.press(at: 0, eligible: true)
        XCTAssertEqual(gesture.interrupt(), [])
        XCTAssertEqual(gesture.tick(at: 0.3), [])
        XCTAssertEqual(gesture.release(at: 1), [])
    }

    func testShortcutDuringHoldCancelsWithoutInsertion() {
        var gesture = DictationHotkeyGesture()
        _ = gesture.press(at: 0, eligible: true)
        _ = gesture.tick(at: 0.3)
        XCTAssertEqual(gesture.interrupt(), [.cancel])
        XCTAssertEqual(gesture.release(at: 1), [])
    }

    func testAnotherModifierAlreadyDownRejectsTrigger() {
        var gesture = DictationHotkeyGesture()
        _ = gesture.press(at: 0, eligible: false)
        XCTAssertEqual(gesture.tick(at: 1), [])
        XCTAssertEqual(gesture.release(at: 2), [])
    }

    func testKeyChangeResetsHoldAndTapHistory() {
        var gesture = DictationHotkeyGesture()
        _ = gesture.press(at: 0, eligible: true)
        _ = gesture.tick(at: 0.3)
        XCTAssertEqual(gesture.reset(), [.cancel])
        XCTAssertEqual(gesture.release(at: 1), [])
        _ = gesture.press(at: 2, eligible: true)
        _ = gesture.release(at: 2.1)
        _ = gesture.reset()
        XCTAssertEqual(gesture.press(at: 2.2, eligible: true), [])
    }

    func testInterveningInputBreaksDoubleTapSequence() {
        var gesture = DictationHotkeyGesture()
        _ = gesture.press(at: 0, eligible: true)
        _ = gesture.release(at: 0.1)
        _ = gesture.interrupt()
        XCTAssertEqual(gesture.press(at: 0.2, eligible: true), [])
    }
}
