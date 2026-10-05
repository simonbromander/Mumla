import AppKit
import ApplicationServices
import Carbon
import MumlaCore
import XCTest
@testable import MumlaMac

@MainActor
final class HotkeyMonitorTests: XCTestCase {
    func testDeniedAccessReportsPermissionInsteadOfSilentlyFailing() {
        let source = FakeHotkeyEventSource()
        source.hasPermission = false
        let monitor = ControlHotkeyMonitor(source: source)
        var statuses: [HotkeyMonitorStatus] = []
        monitor.onStatusChanged = { statuses.append($0) }
        monitor.start()
        XCTAssertEqual(monitor.status, .inputMonitoringRequired)
        XCTAssertEqual(statuses, [.inputMonitoringRequired])
        XCTAssertEqual(source.permissionRequests, 0)
        monitor.stop()
    }

    func testGrantingPermissionInstallsListenerWithoutRelaunch() {
        let source = FakeHotkeyEventSource()
        source.hasPermission = false
        source.grantOnRequest = true
        let monitor = ControlHotkeyMonitor(source: source)
        monitor.start()
        monitor.requestPermission()
        XCTAssertEqual(source.permissionRequests, 1)
        XCTAssertEqual(source.starts, 1)
        XCTAssertTrue(source.isRunning)
        XCTAssertEqual(monitor.status, .active)
        monitor.stop()
    }

    func testReturningFromSettingsRetriesAfterExternalPermissionGrant() {
        let source = FakeHotkeyEventSource()
        source.hasPermission = false
        let monitor = ControlHotkeyMonitor(source: source)
        monitor.start()
        source.hasPermission = true
        monitor.start()
        XCTAssertEqual(source.starts, 1)
        XCTAssertEqual(monitor.status, .active)
        monitor.stop()
    }

    func testCreationFailureWithPermissionReportsRetryNotPermissionPrompt() {
        let source = FakeHotkeyEventSource()
        source.startSucceeds = false
        let monitor = ControlHotkeyMonitor(source: source)
        monitor.start()
        XCTAssertEqual(monitor.status, .unavailable)
        source.startSucceeds = true
        monitor.start()
        XCTAssertEqual(monitor.status, .active)
        monitor.stop()
    }

    func testActiveListenerIsNotReinstalledOrGestureResetOnAppSwitch() {
        let source = FakeHotkeyEventSource()
        var time: TimeInterval = 0
        let monitor = ControlHotkeyMonitor(source: source, now: { time })
        var starts = 0
        var endings = 0
        monitor.onHoldStarted = { starts += 1 }
        monitor.onHoldEnded = { endings += 1 }
        monitor.start()
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        time = 0.25
        monitor.handleHoldThreshold()
        monitor.start()
        source.send(.flagsChanged, keyCode: 59)
        XCTAssertEqual(source.starts, 1)
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(endings, 1)
        monitor.stop()
    }

    func testDeadListenerIsReplacedInsteadOfBlockingAllFurtherStarts() {
        let source = FakeHotkeyEventSource()
        let monitor = ControlHotkeyMonitor(source: source)
        monitor.start()
        source.isRunning = false
        monitor.start()
        XCTAssertEqual(source.starts, 2)
        XCTAssertEqual(monitor.status, .active)
        monitor.stop()
    }

    func testTimeoutCancelsHoldAndReenablesListener() {
        let source = FakeHotkeyEventSource()
        var time: TimeInterval = 0
        let monitor = ControlHotkeyMonitor(source: source, now: { time })
        var cancellations = 0
        var endings = 0
        monitor.onCancel = { cancellations += 1 }
        monitor.onHoldEnded = { endings += 1 }
        monitor.start()
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        time = 0.25
        monitor.handleHoldThreshold()
        source.isRunning = false
        source.send(.tapDisabledByTimeout)
        source.send(.flagsChanged, keyCode: 59)
        XCTAssertEqual(cancellations, 1)
        XCTAssertEqual(endings, 0)
        XCTAssertEqual(source.resumes, 1)
        XCTAssertTrue(source.isRunning)
        XCTAssertEqual(monitor.status, .active)
        monitor.stop()
    }

    func testDisabledListenerCannotPretendToBeActiveWhenResumeFails() {
        let source = FakeHotkeyEventSource()
        let monitor = ControlHotkeyMonitor(source: source)
        monitor.start()
        source.resumeSucceeds = false
        source.isRunning = false
        source.send(.tapDisabledByUserInput)
        XCTAssertEqual(monitor.status, .unavailable)
        XCTAssertFalse(source.isRunning)
        monitor.start()
        XCTAssertEqual(monitor.status, .active)
        monitor.stop()
    }

    func testRevokedPermissionCancelsRecordingAndReportsMissingAccess() {
        let source = FakeHotkeyEventSource()
        var time: TimeInterval = 0
        let monitor = ControlHotkeyMonitor(source: source, now: { time })
        var cancellations = 0
        monitor.onCancel = { cancellations += 1 }
        monitor.start()
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        time = 0.25
        monitor.handleHoldThreshold()
        source.hasPermission = false
        monitor.start()
        XCTAssertEqual(cancellations, 1)
        XCTAssertEqual(monitor.status, .inputMonitoringRequired)
        monitor.stop()
    }

    func testRightOptionSelectionIgnoresControlAndLeftOption() {
        let source = FakeHotkeyEventSource()
        var time: TimeInterval = 0
        let monitor = ControlHotkeyMonitor(source: source, now: { time })
        var starts = 0
        var endings = 0
        monitor.onHoldStarted = { starts += 1 }
        monitor.onHoldEnded = { endings += 1 }
        monitor.setTriggerKey(.rightOption)
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        source.send(.flagsChanged, keyCode: 59)
        source.send(.flagsChanged, keyCode: 58, flags: .maskAlternate)
        time = 1
        monitor.handleHoldThreshold()
        source.send(.flagsChanged, keyCode: 58)
        XCTAssertEqual(starts, 0)
        let rightOption = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | UInt64(NX_DEVICERALTKEYMASK))
        source.send(.flagsChanged, keyCode: 61, flags: rightOption)
        time = 1.25
        monitor.handleHoldThreshold()
        source.send(.flagsChanged, keyCode: 61)
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(endings, 1)
        monitor.stop()
    }

    func testFunctionKeySelectionStartsAndEndsHold() {
        let source = FakeHotkeyEventSource()
        var time: TimeInterval = 0
        let monitor = ControlHotkeyMonitor(source: source, now: { time })
        var starts = 0
        var endings = 0
        monitor.onHoldStarted = { starts += 1 }
        monitor.onHoldEnded = { endings += 1 }
        monitor.setTriggerKey(.function)
        source.send(.flagsChanged, keyCode: 63, flags: .maskSecondaryFn)
        time = 0.25
        monitor.handleHoldThreshold()
        source.send(.flagsChanged, keyCode: 63)
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(endings, 1)
        monitor.stop()
    }

    func testShortcutBeforeHoldThresholdNeverStartsDictation() {
        let source = FakeHotkeyEventSource()
        var time: TimeInterval = 0
        let monitor = ControlHotkeyMonitor(source: source, now: { time })
        var starts = 0
        var endings = 0
        monitor.onHoldStarted = { starts += 1 }
        monitor.onHoldEnded = { endings += 1 }
        monitor.start()
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        source.send(.keyDown, keyCode: 8, flags: .maskControl)
        time = 0.25
        monitor.handleHoldThreshold()
        source.send(.flagsChanged, keyCode: 59)
        XCTAssertEqual(starts, 0)
        XCTAssertEqual(endings, 0)
        monitor.stop()
    }

    func testDoubleTapStartsHandsFreeWithoutAlsoStartingHold() {
        let source = FakeHotkeyEventSource()
        var time: TimeInterval = 0
        let monitor = ControlHotkeyMonitor(source: source, now: { time })
        var doubleTaps = 0
        var holds = 0
        monitor.onDoubleTap = { doubleTaps += 1 }
        monitor.onHoldStarted = { holds += 1 }
        monitor.start()
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        time = 0.1
        source.send(.flagsChanged, keyCode: 59)
        time = 0.2
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        time = 0.5
        monitor.handleHoldThreshold()
        source.send(.flagsChanged, keyCode: 59)
        XCTAssertEqual(doubleTaps, 1)
        XCTAssertEqual(holds, 0)
        monitor.stop()
    }

    func testSecureInputAtThresholdPreventsRecording() {
        let source = FakeHotkeyEventSource()
        var time: TimeInterval = 0
        let monitor = ControlHotkeyMonitor(source: source, now: { time })
        var starts = 0
        monitor.onHoldStarted = { starts += 1 }
        monitor.start()
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        source.isSecureInput = true
        time = 0.25
        monitor.handleHoldThreshold()
        XCTAssertEqual(starts, 0)
        source.isSecureInput = false
        source.send(.flagsChanged, keyCode: 59)
        monitor.stop()
    }

    func testStoppingListenerCancelsPendingHold() {
        let source = FakeHotkeyEventSource()
        var time: TimeInterval = 0
        let monitor = ControlHotkeyMonitor(source: source, now: { time })
        var starts = 0
        monitor.onHoldStarted = { starts += 1 }
        monitor.start()
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        monitor.stop()
        time = 0.25
        monitor.handleHoldThreshold()
        XCTAssertEqual(starts, 0)
        XCTAssertFalse(source.isRunning)
        XCTAssertEqual(monitor.status, .stopped)
    }

    func testLocalOnlySourceCannotReportGlobalReadinessWithoutInputMonitoring() {
        let source = FakeHotkeyEventSource()
        source.hasPermission = false
        source.canStartWithoutPermission = true
        let monitor = ControlHotkeyMonitor(source: source)
        monitor.start()
        XCTAssertEqual(source.starts, 0)
        XCTAssertFalse(source.isRunning)
        XCTAssertEqual(monitor.status, .inputMonitoringRequired)
        monitor.stop()
    }

    func testManualRetryReplacesAnApparentlyHealthyButStaleListener() {
        let source = FakeHotkeyEventSource()
        let monitor = ControlHotkeyMonitor(source: source)
        monitor.start()
        monitor.requestPermission()
        XCTAssertEqual(source.starts, 2)
        XCTAssertEqual(monitor.status, .active)
        monitor.stop()
    }

    func testHoldTimerFiresInDefaultModeWithNoMenuOpenAndAppInactive() {
        XCTAssertFalse(NSApplication.shared.isActive)
        assertNativeHoldTimer(mode: .default)
    }

    func testLocalHoldWorksWithoutClaimingGlobalPermission() {
        let source = FakeHotkeyEventSource()
        source.hasPermission = false
        source.localStartSucceeds = true
        var time: TimeInterval = 0
        let monitor = ControlHotkeyMonitor(source: source, now: { time })
        var starts = 0
        var endings = 0
        monitor.onHoldStarted = { starts += 1 }
        monitor.onHoldEnded = { endings += 1 }
        monitor.start()
        XCTAssertEqual(monitor.status, .inputMonitoringRequired)
        XCTAssertFalse(source.isRunning)
        XCTAssertTrue(source.isLocalRunning)
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        time = 0.25
        monitor.handleHoldThreshold()
        source.send(.flagsChanged, keyCode: 59)
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(endings, 1)
        XCTAssertEqual(monitor.gestureStage, .released)
        monitor.stop()
        XCTAssertFalse(source.isLocalRunning)
    }

    func testEarlyTimerIsRescheduledInsteadOfDroppingHold() {
        let source = FakeHotkeyEventSource()
        var time: TimeInterval = 0
        let monitor = ControlHotkeyMonitor(source: source, now: { time })
        defer { monitor.stop() }
        var starts = 0
        monitor.onHoldStarted = { starts += 1 }
        monitor.start()
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        time = 0.249
        monitor.handleHoldThreshold()
        XCTAssertEqual(starts, 0)
        time = 0.251
        let deadline = Date().addingTimeInterval(0.2)
        while starts == 0, Date() < deadline { _ = RunLoop.main.run(mode: .default, before: deadline) }
        XCTAssertEqual(starts, 1)
    }

    func testSecureInputBlocksLocalHotkeyToo() {
        let source = FakeHotkeyEventSource()
        source.hasPermission = false
        source.localStartSucceeds = true
        source.isSecureInput = true
        let monitor = ControlHotkeyMonitor(source: source)
        defer { monitor.stop() }
        var starts = 0
        monitor.onHoldStarted = { starts += 1 }
        monitor.start()
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        monitor.handleHoldThreshold()
        XCTAssertEqual(starts, 0)
        XCTAssertEqual(monitor.gestureStage, .secureInputBlocked)
    }

    func testHoldTimerAlsoFiresInMenuTrackingMode() {
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), CFRunLoopMode(rawValue: RunLoop.Mode.eventTracking.rawValue as CFString))
        assertNativeHoldTimer(mode: .eventTracking)
    }

    private func assertNativeHoldTimer(mode: RunLoop.Mode, file: StaticString = #filePath, line: UInt = #line) {
        let source = FakeHotkeyEventSource()
        let monitor = ControlHotkeyMonitor(source: source)
        defer { monitor.stop() }
        var starts = 0
        var endings = 0
        monitor.onHoldStarted = { starts += 1 }
        monitor.onHoldEnded = { endings += 1 }
        monitor.start()
        source.send(.flagsChanged, keyCode: 59, flags: .maskControl)
        let deadline = Date().addingTimeInterval(0.75)
        while starts == 0, Date() < deadline { _ = RunLoop.main.run(mode: mode, before: deadline) }
        XCTAssertEqual(starts, 1, file: file, line: line)
        source.send(.flagsChanged, keyCode: 59)
        XCTAssertEqual(endings, 1, file: file, line: line)
    }
}

@MainActor
private final class FakeHotkeyEventSource: HotkeyEventSource {
    var hasPermission = true
    var isRunning = false
    var isLocalRunning = false
    var isSecureInput = false
    var startSucceeds = true
    var resumeSucceeds = true
    var grantOnRequest = false
    var canStartWithoutPermission = false
    var localStartSucceeds = false
    var starts = 0
    var resumes = 0
    var permissionRequests = 0
    private var handler: ((CGEventType, CGEvent) -> Void)?

    func start(handler: @escaping (CGEventType, CGEvent) -> Void) -> Bool {
        starts += 1
        isRunning = (hasPermission || canStartWithoutPermission) && startSucceeds
        self.handler = isRunning ? handler : nil
        return isRunning
    }

    func resume() -> Bool {
        resumes += 1
        isRunning = hasPermission && resumeSucceeds
        return isRunning
    }

    func startLocal(handler: @escaping (CGEventType, CGEvent) -> Void) -> Bool {
        isLocalRunning = localStartSucceeds
        if isLocalRunning { self.handler = handler }
        return isLocalRunning
    }

    func stop() { isRunning = false; isLocalRunning = false; handler = nil }
    func requestPermission() {
        permissionRequests += 1
        if grantOnRequest { hasPermission = true }
    }

    func send(_ type: CGEventType, keyCode: CGKeyCode = 0, flags: CGEventFlags = []) {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
        event.flags = flags
        handler?(type, event)
    }
}
