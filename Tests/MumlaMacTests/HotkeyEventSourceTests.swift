import CoreGraphics
import XCTest
@testable import MumlaMac

@MainActor
final class HotkeyEventSourceTests: XCTestCase {
    func testGlobalListenerWithAllRequiredEventsIsAccepted() {
        XCTAssertTrue(MacHotkeyEventSource.isGlobalListener(validTap(), processID: 123))
    }

    func testLiveSystemDoesNotInstallPartialTapWithoutInputMonitoring() throws {
        guard !CGPreflightListenEventAccess() else {
            throw XCTSkip("This host already grants Input Monitoring to the test process")
        }
        let source = MacHotkeyEventSource()
        defer { source.stop() }
        XCTAssertFalse(source.hasPermission)
        XCTAssertFalse(source.start { _, _ in XCTFail("Denied input must never reach the listener") })
        XCTAssertFalse(source.isRunning)
    }

    func testMouseOnlyTapCannotPretendToListenForHotkeys() {
        var tap = validTap()
        tap.eventsOfInterest = 1 << CGEventType.leftMouseDown.rawValue
        XCTAssertFalse(MacHotkeyEventSource.isGlobalListener(tap, processID: 123))
    }

    func testMissingKeyboardOrCancellationEventsAreRejected() {
        for event in MacHotkeyEventSource.requiredEvents {
            var tap = validTap()
            tap.eventsOfInterest &= ~(1 << CGEventMask(event.rawValue))
            XCTAssertFalse(MacHotkeyEventSource.isGlobalListener(tap, processID: 123), "Missing event: \(event)")
        }
    }

    func testAppLocalTapIsNotAWorkingGlobalHotkey() {
        var tap = validTap()
        tap.processBeingTapped = 123
        XCTAssertFalse(MacHotkeyEventSource.isGlobalListener(tap, processID: 123))
    }

    func testOtherProcessesAndDisabledOrDifferentTapsAreRejected() {
        var tap = validTap()
        XCTAssertFalse(MacHotkeyEventSource.isGlobalListener(tap, processID: 456))
        tap.enabled = false
        XCTAssertFalse(MacHotkeyEventSource.isGlobalListener(tap, processID: 123))
        tap = validTap()
        tap.tapPoint = .cgAnnotatedSessionEventTap
        XCTAssertFalse(MacHotkeyEventSource.isGlobalListener(tap, processID: 123))
        tap = validTap()
        tap.options = .defaultTap
        XCTAssertFalse(MacHotkeyEventSource.isGlobalListener(tap, processID: 123))
    }

    private func validTap() -> CGEventTapInformation {
        var tap = CGEventTapInformation()
        tap.eventTapID = 1
        tap.tappingProcess = 123
        tap.processBeingTapped = 0
        tap.tapPoint = .cgSessionEventTap
        tap.options = .listenOnly
        tap.enabled = true
        tap.eventsOfInterest = MacHotkeyEventSource.requiredEventMask
        return tap
    }
}
