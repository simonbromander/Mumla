import AppKit
import MumlaAudio
import MumlaCore
import XCTest
@testable import MumlaMac

@MainActor
final class MacUpdateTests: XCTestCase {
    private var configuration: [String: Any] {
        ["MumlaDistribution": "direct", "SUFeedURL": "https://example.com/appcast.xml",
         "SUPublicEDKey": Data(repeating: 1, count: 32).base64EncodedString(),
         "SURequireSignedFeed": true, "SUVerifyUpdateBeforeExtraction": true]
    }

    func testValidDirectConfiguration() {
        XCTAssertEqual(MacUpdateConfiguration(info: configuration)?.feedURL.absoluteString, "https://example.com/appcast.xml")
    }

    func testAppStoreAndUnconfiguredAppsHaveNoUpdater() {
        var info = configuration
        info["MumlaDistribution"] = "app-store"
        XCTAssertNil(MacUpdateConfiguration(info: info))
        XCTAssertNil(MacUpdateConfiguration(info: [:]))
        XCTAssertFalse(MacUpdateController().isAvailable)
    }

    func testRejectsInsecureOrCredentialedURLs() {
        for url in ["http://example.com/appcast.xml", "file:///tmp/feed.xml", "https://user:token@example.com/feed.xml", "invalid"] {
            var info = configuration
            info["SUFeedURL"] = url
            XCTAssertNil(MacUpdateConfiguration(info: info))
        }
    }

    func testRejectsMissingOrInvalidSigningKeys() {
        for key in ["", "not-a-key", Data(repeating: 1, count: 31).base64EncodedString()] {
            var info = configuration
            info["SUPublicEDKey"] = key
            XCTAssertNil(MacUpdateConfiguration(info: info))
        }
    }

    func testRequiresSignedFeedAndArchiveVerification() {
        for setting in ["SURequireSignedFeed", "SUVerifyUpdateBeforeExtraction"] {
            var info = configuration
            info[setting] = false
            XCTAssertNil(MacUpdateConfiguration(info: info))
        }
    }

    func testIdleInstallationContinuesWithoutInvokingDeferredHandler() {
        let gate = AppUpdateInstallGate()
        var commitments = 0
        var installs = 0
        gate.onCommit = { commitments += 1 }
        XCTAssertFalse(gate.postponeInstall { installs += 1 })
        XCTAssertTrue(gate.isCommitted)
        XCTAssertFalse(gate.isWaitingForIdle)
        XCTAssertEqual(commitments, 1)
        XCTAssertEqual(installs, 0)
    }

    func testBusyInstallationResumesExactlyOnceWhenWorkEnds() {
        let gate = AppUpdateInstallGate()
        gate.isBusy = true
        var installs = 0
        XCTAssertTrue(gate.postponeInstall { installs += 1 })
        XCTAssertTrue(gate.isWaitingForIdle)
        XCTAssertEqual(installs, 0)
        gate.isBusy = true
        XCTAssertEqual(installs, 0)
        gate.isBusy = false
        gate.isBusy = false
        XCTAssertEqual(installs, 1)
        XCTAssertFalse(gate.isWaitingForIdle)
        XCTAssertTrue(gate.isCommitted)
    }

    func testCancelledUpdateCannotResumeAnOldInstall() {
        let gate = AppUpdateInstallGate()
        gate.isBusy = true
        var installs = 0
        var resets = 0
        gate.onReset = { resets += 1 }
        XCTAssertTrue(gate.postponeInstall { installs += 1 })
        gate.reset()
        gate.isBusy = false
        XCTAssertEqual(installs, 0)
        XCTAssertEqual(resets, 1)
        XCTAssertFalse(gate.isCommitted)
        XCTAssertFalse(gate.isWaitingForIdle)
    }

    func testReentrantIdleNotificationCannotInstallTwice() {
        let gate = AppUpdateInstallGate()
        gate.isBusy = true
        var installs = 0
        XCTAssertTrue(gate.postponeInstall {
            installs += 1
            gate.isBusy = false
        })
        gate.isBusy = false
        XCTAssertEqual(installs, 1)
    }

    func testCommittedUpdatePreventsNewWork() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = AppCoordinator(
            recorder: MicrophoneRecorder(), transcriber: nil,
            historyStore: DictationHistoryStore(directory: directory),
            dictionaryStore: DictionaryStore(directory: directory),
            settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil,
            pasteboard: NSPasteboard(name: .init(UUID().uuidString))
        )
        coordinator.setAppUpdateInstallationInProgress(true)
        await coordinator.startQuickDictation()
        coordinator.pasteRecord(DictationRecord(text: "Hej", language: .swedish))
        coordinator.installModel()
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertFalse(coordinator.isBusyForAppUpdate)
        XCTAssertFalse(coordinator.isInstallingModel)
        coordinator.setAppUpdateInstallationInProgress(false)
        coordinator.pasteRecord(DictationRecord(text: "Hej", language: .swedish))
        XCTAssertTrue(coordinator.isBusyForAppUpdate)
        for _ in 0..<100 {
            if !coordinator.isBusyForAppUpdate { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(coordinator.isBusyForAppUpdate)
    }
}
