import FluidAudio
import XCTest
@testable import MumlaAudio

final class LocalPianissimoPreparationTests: XCTestCase, @unchecked Sendable {
    func testConcurrentPreparationSharesOneLoadAndWarmStartsReuseIt() async throws {
        let probe = ManagerLoadProbe()
        let transcriber = LocalPianissimoTranscriber(managerLoader: { try await probe.load() })
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<12 { group.addTask { try await transcriber.warmUp() } }
            try await group.waitForAll()
        }
        try await transcriber.warmUp()
        let count = await probe.count
        XCTAssertEqual(count, 1)
    }

    func testFailedPreparationCanBeRetried() async throws {
        let probe = ManagerLoadProbe(failFirst: true)
        let transcriber = LocalPianissimoTranscriber(managerLoader: { try await probe.load() })
        do {
            try await transcriber.warmUp()
            XCTFail("The first load should fail")
        } catch { XCTAssertTrue(error is PreparationFailure) }
        try await transcriber.warmUp()
        try await transcriber.warmUp()
        let count = await probe.count
        XCTAssertEqual(count, 2)
    }

    func testCancelledPreparationDoesNotCancelAnotherWaiter() async throws {
        let probe = ManagerLoadProbe()
        let transcriber = LocalPianissimoTranscriber(managerLoader: { try await probe.load() })
        let cancelled = Task { try await transcriber.warmUp() }
        await probe.waitUntilLoading()
        let remaining = Task { try await transcriber.warmUp() }
        cancelled.cancel()
        do {
            try await cancelled.value
            XCTFail("Cancelled waiter should not report readiness")
        } catch { XCTAssertTrue(error is CancellationError) }
        try await remaining.value
        try await transcriber.warmUp()
        let count = await probe.count
        XCTAssertEqual(count, 1)
    }

    func testMissingLocalModelFailsWithoutDownloading() async {
        let transcriber = LocalPianissimoTranscriber(modelDirectory: URL(fileURLWithPath: "/nonexistent-mumla-model"))
        do {
            try await transcriber.warmUp()
            XCTFail("A missing local model must fail")
        } catch { XCTAssertFalse(error is CancellationError) }
    }
}

private enum PreparationFailure: Error { case unavailable }

private actor ManagerLoadProbe {
    private(set) var count = 0
    let failFirst: Bool
    private var started: [CheckedContinuation<Void, Never>] = []

    init(failFirst: Bool = false) { self.failFirst = failFirst }

    func waitUntilLoading() async {
        if count > 0 { return }
        await withCheckedContinuation { started.append($0) }
    }

    func load() async throws -> AsrManager {
        count += 1
        for waiter in started { waiter.resume() }
        started = []
        try await Task.sleep(for: .milliseconds(50))
        if failFirst && count == 1 { throw PreparationFailure.unavailable }
        return AsrManager(config: ASRConfig())
    }
}
