import Foundation
import XCTest
@testable import MumlaCore

final class TranscriptDestinationTests: XCTestCase {
    private func endpoint(scheme: String = "https") -> URL {
        var parts = URLComponents(); parts.scheme = scheme; parts.host = UUID().uuidString.lowercased() + ".invalid"
        parts.path = "/transcript"; return parts.url!
    }
    private func payload() throws -> OutgoingTranscript {
        try OutgoingTranscript(text: "  Första raden.\n\n" + String(repeating: "Åäö 🗣️ ", count: 25), language: .swedish,
                               recordedAt: Date(timeIntervalSince1970: 1_700_000_000), durationSeconds: 12.5, version: "1.2.3")
    }

    func testRequestContainsOnlyExpectedTextFieldsAndExplicitCredentials() async throws {
        let url = endpoint(), token = UUID().uuidString
        let client = DestinationHTTPStub(status: 201), tokens = DestinationTokensStub()
        try tokens.save(token, for: url)
        let value = try payload()
        let result = await TranscriptSender(client: client, tokens: tokens).send(value, to: try TranscriptDestination(name: "My destination", url: url))
        XCTAssertEqual(result, .sent(statusCode: 201))
        let requests = await client.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url, url); XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.timeoutInterval, 15)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer " + token)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["title", "description", "source", "language", "recorded_at", "duration_seconds", "client"]))
        XCTAssertEqual(json["description"] as? String, value.description)
        XCTAssertEqual((json["title"] as? String)?.count, 80)
        XCTAssertFalse((json["title"] as! String).contains("\n"))
        XCTAssertEqual(json["source"] as? String, "voice"); XCTAssertEqual(json["language"] as? String, "sv")
        XCTAssertEqual(json["recorded_at"] as? String, "2023-11-14T22:13:20Z")
        XCTAssertEqual(json["duration_seconds"] as? Double, 12.5); XCTAssertEqual(json["client"] as? String, "mumla/1.2.3")
    }

    func testHTTPStatusesTimeoutAndNoRetries() async throws {
        let url = endpoint(), tokens = DestinationTokensStub(); try tokens.save(UUID().uuidString, for: url)
        let destination = try TranscriptDestination(name: "Destination", url: url)
        for (code, expected) in [(200, TranscriptSendResult.sent(statusCode: 200)), (204, .sent(statusCode: 204)),
                                 (401, .unauthorized), (403, .rejected(statusCode: 403)), (307, .rejected(statusCode: 307)),
                                 (429, .rejected(statusCode: 429)), (503, .rejected(statusCode: 503))] {
            let client = DestinationHTTPStub(status: code)
            let result = await TranscriptSender(client: client, tokens: tokens).send(try payload(), to: destination)
            XCTAssertEqual(result, expected)
            let count = await client.requests.count; XCTAssertEqual(count, 1)
        }
        let client = DestinationHTTPStub(error: .timedOut)
        let result = await TranscriptSender(client: client, tokens: tokens).send(try payload(), to: destination)
        XCTAssertEqual(result, .network(.timeout))
        let count = await client.requests.count; XCTAssertEqual(count, 1)
    }

    func testMissingDestinationOrTokenDoesNotRequestAnything() async throws {
        let client = DestinationHTTPStub(status: 200), tokens = DestinationTokensStub()
        let sender = TranscriptSender(client: client, tokens: tokens)
        let missing = await sender.send(try payload(), to: nil)
        let noToken = await sender.send(try payload(), to: try TranscriptDestination(name: "Destination", url: endpoint()))
        XCTAssertEqual(missing, .notConfigured); XCTAssertEqual(noToken, .notConfigured)
        let count = await client.requests.count; XCTAssertEqual(count, 0)
    }

    func testHTTPSOnlyAndNoEmbeddedCredentialsOrFragment() throws {
        for scheme in ["http", "file", "ftp"] {
            XCTAssertThrowsError(try TranscriptDestination(name: "Destination", url: endpoint(scheme: scheme)))
        }
        var parts = URLComponents(url: endpoint(), resolvingAgainstBaseURL: false)!
        parts.user = "user"; XCTAssertFalse(TranscriptDestination.accepts(parts.url!))
        parts.user = nil; parts.fragment = "fragment"; XCTAssertFalse(TranscriptDestination.accepts(parts.url!))
        XCTAssertThrowsError(try TranscriptDestination(name: " ", url: endpoint()))
        XCTAssertThrowsError(try OutgoingTranscript(text: " \n ", language: .english, recordedAt: Date(), durationSeconds: 0, version: "1"))
    }

    func testSettingsStoreHasNoTokenAndInvalidDestinationDoesNotLosePreferences() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppSettingsStore(directory: directory), url = endpoint(), token = UUID().uuidString
        let tokens = DestinationTokensStub(); try tokens.save(token, for: url)
        try store.save(AppSettings(soundFeedbackEnabled: false, triggerKey: .rightOption))
        try store.setTranscriptDestination(TranscriptDestination(name: "Destination", url: url))
        let data = try Data(contentsOf: directory.appendingPathComponent("settings.json"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(token))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["transcriptDestination"] = ["name": "Destination", "url": endpoint(scheme: "http").absoluteString]
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.transcriptDestination); XCTAssertFalse(decoded.soundFeedbackEnabled); XCTAssertEqual(decoded.triggerKey, .rightOption)
    }

    func testOldHistoryLoadsAndReceiptPreservesCurrentText() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DictationHistoryStore(directory: directory)
        let record = DictationRecord(text: "hej där", language: .swedish, durationMilliseconds: 2500)
        let encoded = try JSONEncoder().encode(record)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("sentAt"))
        XCTAssertNil(try JSONDecoder().decode(DictationRecord.self, from: encoded).sentAt)
        try store.append(record)
        try store.applyFormatting(recordID: record.id, expectedText: record.text, formattedText: "Hej där.")
        let date = Date()
        let changed = try store.markSent(recordID: record.id, at: date)
        XCTAssertEqual(changed.first?.text, "Hej där."); XCTAssertEqual(changed.first?.sentAt, date)
        XCTAssertEqual(try record.outgoingTranscript(version: "1").durationSeconds, 2.5)
        try store.clear()
        XCTAssertThrowsError(try store.markSent(recordID: record.id, at: date))
        XCTAssertTrue(try store.load().isEmpty)
    }

    func testVoiceNoteReceiptDoesNotChangeWatchDeliveryIdentityOrTransferBytes() throws {
        var note = VoiceNote(duration: 10, language: "sv", audioSHA256: String(repeating: "a", count: 64), audioByteCount: 1000, transcript: "En anteckning.")
        let before = try note.transferData(), identity = note.deliveryID
        XCTAssertNil(try JSONDecoder().decode(VoiceNote.self, from: before).sentAt)
        note.sentAt = Date(); note.delivered = true
        XCTAssertEqual(try note.transferData(), before); XCTAssertEqual(note.deliveryID, identity)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: note.outgoingTranscript(version: "1").encoded()) as? [String: Any])
        XCTAssertFalse(json.keys.contains("audioSHA256")); XCTAssertEqual(json["description"] as? String, note.transcript)
    }

    func testRedirectGuardNeverForwardsPostOrToken() {
        let url = endpoint(), session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: url), guardDelegate = TranscriptRequestGuard()
        let response = HTTPURLResponse(url: url, statusCode: 307, httpVersion: nil, headerFields: nil)!
        var redirected = URLRequest(url: endpoint())
        redirected.setValue("Bearer " + UUID().uuidString, forHTTPHeaderField: "Authorization")
        let called = expectation(description: "Redirect declined")
        guardDelegate.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: redirected) { next in
            XCTAssertNil(next); called.fulfill()
        }
        wait(for: [called], timeout: 1)
    }

    func testURLSessionAdapterWithIsolatedProtocolDoesNotRetryOnTimeout() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DestinationTimeoutProtocol.self]
        let result = await TranscriptSender(client: URLSessionTranscriptClient(configuration: configuration), tokens: AlwaysPresentToken())
            .send(try payload(), to: try TranscriptDestination(name: "Destination", url: endpoint()))
        XCTAssertEqual(result, .network(.timeout))
        // A unique URL per test keeps the request count independent of concurrent tests.
        let requests = DestinationTimeoutProtocol.count
        XCTAssertEqual(requests, 1)
    }
}

private struct AlwaysPresentToken: DestinationTokenStoring {
    func save(_ token: String, for url: URL) throws {}
    func delete(for url: URL) throws {}
    func read(for url: URL) throws -> String? { UUID().uuidString }
}
private final class DestinationTimeoutProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var requests = 0
    static var count: Int { lock.withLock { requests } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.withLock { Self.requests += 1 }
        client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
    }
    override func stopLoading() {}
}

private actor DestinationHTTPStub: TranscriptHTTPClient {
    var requests: [URLRequest] = []
    let status: Int
    let error: URLError.Code?
    init(status: Int = 200, error: URLError.Code? = nil) { self.status = status; self.error = error }
    func post(_ request: URLRequest) async throws -> HTTPURLResponse {
        requests.append(request)
        if let error { throw URLError(error, userInfo: [NSURLErrorFailingURLErrorKey: request.url!]) }
        return HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}

private final class DestinationTokensStub: DestinationTokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [URL: String] = [:]
    func save(_ token: String, for url: URL) throws { lock.withLock { values[url] = token } }
    func read(for url: URL) throws -> String? { lock.withLock { values[url] } }
    func delete(for url: URL) throws { _ = lock.withLock { values.removeValue(forKey: url) } }
}
