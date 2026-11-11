import Foundation
import MumlaCore
import MumlaUI
import XCTest

@MainActor
final class DestinationControllerTests: XCTestCase {
    func testSaveDoesNotSendTestIsSyntheticAndRemoveDeletesCredentials() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = AppSettingsStore(directory: directory), tokens = ControllerTokens(), client = ControllerClient()
        let controller = TranscriptDestinationController(settings: settings, tokens: tokens, client: client)
        var parts = URLComponents(); parts.scheme = "https"; parts.host = "receiver.invalid"
        let url = parts.url!, token = UUID().uuidString
        XCTAssertTrue(controller.save(name: "Test destination", address: url.absoluteString, token: token))
        let before = await client.requests.count; XCTAssertEqual(before, 0)
        XCTAssertEqual(try tokens.read(for: url), token)
        await controller.test()
        let requests = await client.requests
        XCTAssertEqual(requests.count, 1)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests.first?.httpBody)) as? [String: Any])
        XCTAssertEqual(body["description"] as? String, "Mumla test transcript.")
        XCTAssertTrue(controller.results.isEmpty)
        controller.remove()
        XCTAssertNil(controller.destination); XCTAssertNil(try settings.load().transcriptDestination)
        XCTAssertNil(try tokens.read(for: url))
    }

    func testChangedAddressRequiresNewTokenAndInvalidSaveKeepsOriginal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = AppSettingsStore(directory: directory), tokens = ControllerTokens()
        let controller = TranscriptDestinationController(settings: settings, tokens: tokens, client: ControllerClient())
        var parts = URLComponents(); parts.scheme = "https"; parts.host = "receiver.invalid"
        let old = parts.url!, token = UUID().uuidString
        XCTAssertTrue(controller.save(name: "First", address: old.absoluteString, token: token))
        parts.path = "/other"; let next = parts.url!
        XCTAssertFalse(controller.save(name: "Other", address: next.absoluteString, token: ""))
        XCTAssertEqual(controller.destination?.url, old); XCTAssertEqual(try tokens.read(for: old), token)
        XCTAssertTrue(controller.save(name: "Renamed", address: old.absoluteString, token: ""))
        XCTAssertEqual(try tokens.read(for: old), token)
        XCTAssertTrue(controller.save(name: "Other", address: next.absoluteString, token: UUID().uuidString))
        XCTAssertNil(try tokens.read(for: old))
    }

    func testReceiptFailureIsStillSentAndChangedDestinationCannotSend() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = AppSettingsStore(directory: directory), tokens = ControllerTokens(), client = ControllerClient()
        let controller = TranscriptDestinationController(settings: settings, tokens: tokens, client: client)
        var parts = URLComponents(); parts.scheme = "https"; parts.host = "receiver.invalid"
        XCTAssertTrue(controller.save(name: "Destination", address: parts.url!.absoluteString, token: UUID().uuidString))
        let approved = try XCTUnwrap(controller.destination), record = DictationRecord(text: "One transcript.", language: .english)
        let value = try record.outgoingTranscript(version: "1")
        let result = await controller.send(value, id: record.id, approvedDestination: approved) { _ in throw CocoaError(.fileWriteNoPermission) }
        XCTAssertEqual(result, .sent(statusCode: 201)); XCTAssertTrue(controller.wasSent(record.id, sentAt: nil))
        XCTAssertTrue(controller.results[record.id]?.contains("Sent") == true || controller.results[record.id]?.contains("Skickat") == true)
        controller.remove()
        let cancelled = await controller.send(value, id: record.id, approvedDestination: approved) { _ in XCTFail("Must not mark") }
        XCTAssertNil(cancelled)
        let count = await client.requests.count; XCTAssertEqual(count, 1)
    }

    func testSettingsFailureRollsBackKeychain() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data().write(to: directory)
        let tokens = ControllerTokens()
        let controller = TranscriptDestinationController(settings: AppSettingsStore(directory: directory), tokens: tokens, client: ControllerClient())
        var parts = URLComponents(); parts.scheme = "https"; parts.host = "receiver.invalid"
        XCTAssertFalse(controller.save(name: "Destination", address: parts.url!.absoluteString, token: UUID().uuidString))
        XCTAssertNil(controller.destination); XCTAssertNil(try tokens.read(for: parts.url!))
    }

    func testConcurrentTapDoesNotSendTwiceOrAllowConfigurationChanges() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = ControllerClient(delay: true)
        let controller = TranscriptDestinationController(settings: AppSettingsStore(directory: directory), tokens: ControllerTokens(), client: client)
        var parts = URLComponents(); parts.scheme = "https"; parts.host = "receiver.invalid"
        XCTAssertTrue(controller.save(name: "Destination", address: parts.url!.absoluteString, token: UUID().uuidString))
        let destination = try XCTUnwrap(controller.destination), record = DictationRecord(text: "A transcript.", language: .english)
        let payload = try record.outgoingTranscript(version: "1")
        let first = Task { await controller.send(payload, id: record.id, approvedDestination: destination) { _ in } }
        while !controller.isSending { await Task.yield() }
        let second = await controller.send(payload, id: record.id, approvedDestination: destination) { _ in XCTFail("Duplicate send") }
        XCTAssertNil(second)
        XCTAssertFalse(controller.save(name: "Changed", address: parts.url!.absoluteString, token: UUID().uuidString))
        controller.remove(); XCTAssertEqual(controller.destination, destination)
        _ = await first.value
        let count = await client.requests.count; XCTAssertEqual(count, 1); XCTAssertFalse(controller.isSending)
    }
}

private final class ControllerTokens: DestinationTokenStoring, @unchecked Sendable {
    private let lock = NSLock(); private var values: [URL: String] = [:]
    func save(_ token: String, for url: URL) throws { lock.withLock { values[url] = token } }
    func read(for url: URL) throws -> String? { lock.withLock { values[url] } }
    func delete(for url: URL) throws { _ = lock.withLock { values.removeValue(forKey: url) } }
}
private actor ControllerClient: TranscriptHTTPClient {
    var requests: [URLRequest] = []
    let delay: Bool
    init(delay: Bool = false) { self.delay = delay }
    func post(_ request: URLRequest) async throws -> HTTPURLResponse {
        requests.append(request)
        if delay { try await Task.sleep(for: .milliseconds(100)) }
        return HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
    }
}
