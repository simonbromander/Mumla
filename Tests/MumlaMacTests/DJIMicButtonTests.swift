import AppKit
import Carbon
import MumlaAudio
import MumlaCore
import XCTest
@testable import MumlaMac

final class DJIMicButtonFilterTests: XCTestCase {
    func testBothVolumeUsagesTriggerOncePerShortTap() {
        for usage: UInt32 in [0xe9, 0xea] {
            var filter = DJIMicButtonFilter()
            XCTAssertFalse(filter.accepts(event(usage: usage, value: 1, time: 1)))
            XCTAssertFalse(filter.accepts(event(usage: usage, value: 1, time: 1.05)))
            XCTAssertTrue(filter.accepts(event(usage: usage, value: 0, time: 1.1)))
            XCTAssertFalse(filter.accepts(event(usage: usage, value: 0, time: 1.11)))
            XCTAssertFalse(filter.accepts(event(usage: usage, value: 1, time: 2)))
            XCTAssertTrue(filter.accepts(event(usage: usage, value: 0, time: 2.1)))
        }
    }

    func testKeyboardVolumeAndOtherReceiversCannotTrigger() {
        for (vendor, product, page, usage) in [(1452, 0x4011, 12, 233), (0x2ca3, 1, 12, 233),
                                               (0x2ca3, 0x4011, 7, 233), (0x2ca3, 0x4011, 12, 226)] {
            var filter = DJIMicButtonFilter()
            for value in [1, 0] {
                let event = DJIMicButtonEvent(deviceID: 1, vendorID: vendor, productID: product,
                                             usagePage: UInt32(page), usage: UInt32(usage), value: value, timestamp: 1)
                XCTAssertFalse(filter.accepts(event))
            }
        }
    }

    func testPairedVolumeReportsAndBounceCauseOnlyOneToggle() {
        var filter = DJIMicButtonFilter()
        XCTAssertFalse(filter.accepts(event(usage: 0xe9, value: 1, time: 1)))
        XCTAssertFalse(filter.accepts(event(usage: 0xea, value: 1, time: 1)))
        XCTAssertTrue(filter.accepts(event(usage: 0xe9, value: 0, time: 1.01)))
        XCTAssertFalse(filter.accepts(event(usage: 0xea, value: 0, time: 1.02)))
        XCTAssertFalse(filter.accepts(event(value: 1, time: 1.03)))
        XCTAssertFalse(filter.accepts(event(value: 0, time: 1.04)))
    }

    func testReportedPairingHoldAndOrphanReleaseCannotStartRecording() {
        var filter = DJIMicButtonFilter()
        XCTAssertFalse(filter.accepts(event(value: 0, time: 1)))
        XCTAssertFalse(filter.accepts(event(value: 1, time: 2)))
        XCTAssertFalse(filter.accepts(event(value: 1, time: 3)))
        XCTAssertFalse(filter.accepts(event(value: 0, time: 4)))
        XCTAssertFalse(filter.accepts(event(value: 1, time: 5)))
        XCTAssertTrue(filter.accepts(event(value: 0, time: 5.1)))
    }

    func testDisconnectDropsHeldStateAndEachReceiverHasIndependentDebounce() {
        var filter = DJIMicButtonFilter()
        _ = filter.accepts(event(device: 1, value: 1, time: 1))
        filter.disconnect(1)
        XCTAssertFalse(filter.accepts(event(device: 1, value: 0, time: 1.1)))
        for id: UInt64 in [1, 2] {
            _ = filter.accepts(event(device: id, value: 1, time: 2))
            XCTAssertTrue(filter.accepts(event(device: id, value: 0, time: 2.1)))
        }
    }

    func testInvalidTimestampsAndValuesAreRejected() {
        for time in [Double.nan, .infinity, -.infinity] {
            var filter = DJIMicButtonFilter()
            XCTAssertFalse(filter.accepts(event(value: 1, time: time)))
            XCTAssertFalse(filter.accepts(event(value: 0, time: time)))
        }
        var filter = DJIMicButtonFilter()
        XCTAssertFalse(filter.accepts(event(value: -1, time: 1)))
        _ = filter.accepts(event(value: 1, time: 2))
        XCTAssertFalse(filter.accepts(event(value: 0, time: 1)))
    }

    private func event(device: UInt64 = 1, usage: UInt32 = 0xe9, value: Int, time: TimeInterval) -> DJIMicButtonEvent {
        DJIMicButtonEvent(deviceID: device, vendorID: 0x2ca3, productID: 0x4011,
                          usagePage: 12, usage: usage, value: value, timestamp: time)
    }
}

@MainActor
final class DJIMicButtonMonitorTests: XCTestCase {
    func testDisabledOrDeniedListenerNeverOpensTheReceiverOrRequestsPermissionOnLaunch() {
        let source = FakeDJIEventSource()
        let monitor = DJIMicButtonMonitor(source: source, helperIsRunning: { false })
        monitor.refresh()
        XCTAssertEqual(monitor.status, .off)
        XCTAssertEqual(source.starts, 0)
        source.hasPermission = false
        monitor.setEnabled(true)
        XCTAssertEqual(monitor.status, .permissionRequired)
        XCTAssertEqual(source.starts, 0)
        XCTAssertEqual(source.permissionRequests, 0)
        monitor.requestPermission()
        XCTAssertEqual(source.permissionRequests, 1)
    }

    func testHelperConflictDoesNotCompeteForTheReceiverAndRecoversAfterQuit() {
        let source = FakeDJIEventSource()
        var helperRunning = true
        let monitor = DJIMicButtonMonitor(source: source, helperIsRunning: { helperRunning })
        monitor.setEnabled(true)
        XCTAssertEqual(monitor.status, .helperRunning)
        XCTAssertEqual(source.starts, 0)
        helperRunning = false
        monitor.refresh()
        XCTAssertEqual(source.starts, 1)
        XCTAssertEqual(monitor.status, .ready)
        helperRunning = true
        monitor.refresh()
        XCTAssertEqual(monitor.status, .helperRunning)
        XCTAssertFalse(source.isRunning)
    }

    func testOneTapDeliversOneDirectActionWithoutKeyboardEvents() async {
        let source = FakeDJIEventSource()
        let monitor = DJIMicButtonMonitor(source: source, helperIsRunning: { false })
        var receivers: [UInt64] = []
        monitor.onPress = { receivers.append($0) }
        monitor.setEnabled(true)
        source.tap()
        await drain()
        XCTAssertEqual(receivers, [1])
        monitor.refresh()
        XCTAssertEqual(source.starts, 1)
    }

    func testDisableAndSleepInvalidateAlreadyQueuedPressesAndOldCallbacks() async {
        for disable in [true, false] {
            let source = FakeDJIEventSource()
            let monitor = DJIMicButtonMonitor(source: source, helperIsRunning: { false })
            var presses = 0
            monitor.onPress = { _ in presses += 1 }
            monitor.setEnabled(true)
            let stale = source.value
            source.tap()
            if disable { monitor.setEnabled(false) } else { monitor.suspend() }
            await drain()
            XCTAssertEqual(presses, 0)
            XCTAssertFalse(source.isRunning)
            monitor.resume()
            if disable { monitor.setEnabled(true) }
            stale?(source.event(value: 1, time: 3))
            stale?(source.event(value: 0, time: 3.1))
            source.tap(time: 4)
            await drain()
            XCTAssertEqual(presses, 1)
        }
    }

    func testReceiverRemovalClearsHeldPressAndNotifiesOwner() async {
        let source = FakeDJIEventSource()
        let monitor = DJIMicButtonMonitor(source: source, helperIsRunning: { false })
        var removed: [UInt64] = []
        var presses = 0
        monitor.onPress = { _ in presses += 1 }
        monitor.onDisconnect = { removed.append($0) }
        monitor.setEnabled(true)
        source.value?(source.event(value: 1, time: 1))
        source.disconnected?(1)
        source.value?(source.event(value: 0, time: 1.1))
        await drain()
        XCTAssertEqual(removed, [1])
        XCTAssertEqual(presses, 0)
    }

    func testShutdownStopsTheListenerAndCannotRestartFromActivation() {
        let source = FakeDJIEventSource()
        let monitor = DJIMicButtonMonitor(source: source, helperIsRunning: { false })
        monitor.setEnabled(true)
        monitor.stop()
        monitor.refresh()
        XCTAssertEqual(monitor.status, .off)
        XCTAssertFalse(source.isRunning)
    }

    private func drain() async { for _ in 0..<10 { await Task.yield() } }
}

@MainActor
private final class FakeDJIEventSource: DJIMicButtonEventSource {
    var hasPermission = true
    var isRunning = false
    var starts = 0
    var permissionRequests = 0
    var value: ((DJIMicButtonEvent) -> Void)?
    var disconnected: ((UInt64) -> Void)?
    func start(value: @escaping (DJIMicButtonEvent) -> Void,
               status: @escaping (DJIMicButtonStatus) -> Void, disconnected: @escaping (UInt64) -> Void) {
        starts += 1; isRunning = true
        self.value = value; self.disconnected = disconnected
        status(.ready)
    }
    func stop() { isRunning = false; value = nil; disconnected = nil }
    func requestPermission() { permissionRequests += 1 }
    func event(value: Int, time: TimeInterval) -> DJIMicButtonEvent {
        DJIMicButtonEvent(deviceID: 1, vendorID: 0x2ca3, productID: 0x4011,
                          usagePage: 12, usage: 0xe9, value: value, timestamp: time)
    }
    func tap(time: TimeInterval = 1) { value?(event(value: 1, time: time)); value?(event(value: 0, time: time + 0.1)) }
}

@MainActor
final class DJIMicCoordinatorTests: XCTestCase {
    func testSettingPersistsAndRestoresWithoutRequestingPermissionOnStartup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory)
        var enabled: [Bool] = []
        var permissionRequests = 0
        coordinator.djiMicButtonEnabledChanged = { enabled.append($0) }
        coordinator.requestDJIMicAccess = { permissionRequests += 1 }
        coordinator.setDJIMicButtonEnabled(true)
        XCTAssertTrue(try AppSettingsStore(directory: directory).load().djiMicButtonEnabled)
        XCTAssertEqual(enabled, [true])
        XCTAssertEqual(permissionRequests, 1)
        let restored = makeCoordinator(directory)
        restored.djiMicButtonEnabledChanged = { enabled.append($0) }
        restored.requestDJIMicAccess = { permissionRequests += 1 }
        restored.bootstrap()
        XCTAssertEqual(enabled, [true, true])
        XCTAssertEqual(permissionRequests, 1)
        restored.setDJIMicButtonEnabled(false)
        XCTAssertFalse(try AppSettingsStore(directory: directory).load().djiMicButtonEnabled)
    }

    func testButtonUsesExistingModelGateAndDoesNothingWhileDisabledOrUpdating() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory)
        await coordinator.djiMicButtonPressed(receiverID: 1)
        XCTAssertEqual(coordinator.pillState, .hidden)
        coordinator.setDJIMicButtonEnabled(true)
        coordinator.setAppUpdateInstallationInProgress(true)
        await coordinator.djiMicButtonPressed(receiverID: 1)
        XCTAssertEqual(coordinator.pillState, .hidden)
        coordinator.setAppUpdateInstallationInProgress(false)
        await coordinator.djiMicButtonPressed(receiverID: 1)
        if !IsSecureEventInputEnabled() { XCTAssertEqual(coordinator.pillState, .message("Download model first")) }
    }

    private func makeCoordinator(_ directory: URL) -> AppCoordinator {
        AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil,
            historyStore: DictationHistoryStore(directory: directory), dictionaryStore: DictionaryStore(directory: directory),
            settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil,
            pasteboard: NSPasteboard(name: .init(UUID().uuidString)))
    }
}
