import Foundation

public enum TranscriptDestinationError: Error, Equatable, Sendable {
    case invalidName, invalidAddress, emptyTranscript, invalidMetadata
}

public struct TranscriptDestination: Codable, Equatable, Sendable {
    public let name: String
    public let url: URL

    public init(name: String, url: URL) throws {
        let name = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty, name.count <= 80, !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw TranscriptDestinationError.invalidName
        }
        guard Self.accepts(url) else { throw TranscriptDestinationError.invalidAddress }
        self.name = name; self.url = url
    }

    public static func accepts(_ url: URL) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        return parts.scheme?.lowercased() == "https" && !(parts.host?.isEmpty ?? true)
            && parts.user == nil && parts.password == nil && parts.fragment == nil
    }

    private enum CodingKeys: String, CodingKey { case name, url }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(name: values.decode(String.self, forKey: .name), url: values.decode(URL.self, forKey: .url))
    }
}

/// Deliberately accepts no recording object, attachment, file URL or history.
public struct OutgoingTranscript: Encodable, Equatable, Sendable {
    public let title: String
    public let description: String
    public let source = "voice"
    public let language: MumlaLanguage
    public let recordedAt: Date
    public let durationSeconds: Double
    public let client: String

    public init(text: String, language: MumlaLanguage, recordedAt: Date, durationSeconds: Double, version: String) throws {
        let preview = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !preview.isEmpty else { throw TranscriptDestinationError.emptyTranscript }
        guard durationSeconds.isFinite, durationSeconds >= 0, recordedAt.timeIntervalSince1970.isFinite,
              !version.isEmpty, version.count <= 80 else { throw TranscriptDestinationError.invalidMetadata }
        title = String(preview.prefix(80)); description = text; self.language = language
        self.recordedAt = recordedAt; self.durationSeconds = durationSeconds; client = "mumla/" + version
    }

    private enum CodingKeys: String, CodingKey {
        case title, description, source, language, client
        case recordedAt = "recorded_at", durationSeconds = "duration_seconds"
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

public extension DictationRecord {
    func outgoingTranscript(version: String) throws -> OutgoingTranscript {
        try OutgoingTranscript(text: text, language: language, recordedAt: createdAt,
                               durationSeconds: (durationMilliseconds ?? 0) / 1_000, version: version)
    }
}

public extension VoiceNote {
    func outgoingTranscript(version: String) throws -> OutgoingTranscript {
        guard let language = MumlaLanguage(rawValue: language) else { throw TranscriptDestinationError.invalidMetadata }
        return try OutgoingTranscript(text: transcript ?? "", language: language, recordedAt: createdAt,
                                      durationSeconds: duration, version: version)
    }
}

public enum TranscriptNetworkFailure: Equatable, Sendable {
    case timeout, offline, secureConnection, cancelled, other(Int)
    public init(_ error: Error) {
        if error is CancellationError { self = .cancelled; return }
        let code = (error as? URLError)?.code ?? .unknown
        switch code {
        case .timedOut: self = .timeout
        case .notConnectedToInternet: self = .offline
        case .cancelled: self = .cancelled
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid: self = .secureConnection
        default: self = .other(code.rawValue)
        }
    }
}

public enum TranscriptSendResult: Equatable, Sendable {
    case sent(statusCode: Int), unauthorized, rejected(statusCode: Int)
    case network(TranscriptNetworkFailure), notConfigured
}

public protocol TranscriptHTTPClient: Sendable {
    func post(_ request: URLRequest) async throws -> HTTPURLResponse
}

public final class URLSessionTranscriptClient: TranscriptHTTPClient, @unchecked Sendable {
    private let session: URLSession
    public init(configuration: URLSessionConfiguration = .ephemeral) {
        let safe = configuration.copy() as? URLSessionConfiguration ?? .ephemeral
        safe.urlCache = nil; safe.httpCookieStorage = nil; safe.urlCredentialStorage = nil
        safe.httpShouldSetCookies = false; safe.waitsForConnectivity = false
        safe.requestCachePolicy = .reloadIgnoringLocalCacheData
        safe.timeoutIntervalForRequest = 15; safe.timeoutIntervalForResource = 15
        session = URLSession(configuration: safe)
    }

    public func post(_ request: URLRequest) async throws -> HTTPURLResponse {
        let guardDelegate = TranscriptRequestGuard()
        do {
            let (bytes, response) = try await session.bytes(for: request, delegate: guardDelegate)
            // Only the HTTP status is needed; never collect or log a receiver's body.
            bytes.task.cancel()
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            return response
        } catch {
            if let response = guardDelegate.authenticationFailure { return response }
            throw error
        }
    }
}

final class TranscriptRequestGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var failure: HTTPURLResponse?
    var authenticationFailure: HTTPURLResponse? { lock.withLock { failure } }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else {
            lock.withLock { failure = challenge.failureResponse as? HTTPURLResponse }
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

public struct TranscriptSender: Sendable {
    private let client: any TranscriptHTTPClient
    private let tokens: any DestinationTokenStoring
    public init(client: any TranscriptHTTPClient = URLSessionTranscriptClient(), tokens: any DestinationTokenStoring = DestinationTokenStore()) {
        self.client = client; self.tokens = tokens
    }

    public func send(_ transcript: OutgoingTranscript, to destination: TranscriptDestination?) async -> TranscriptSendResult {
        guard let destination, TranscriptDestination.accepts(destination.url),
              let token = try? tokens.read(for: destination.url), DestinationTokenStore.accepts(token) else { return .notConfigured }
        do {
            try Task.checkCancellation()
            var request = URLRequest(url: destination.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.httpMethod = "POST"; request.httpBody = try transcript.encoded()
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            let response = try await client.post(request)
            switch response.statusCode {
            case 200..<300: return .sent(statusCode: response.statusCode)
            case 401: return .unauthorized
            default: return .rejected(statusCode: response.statusCode)
            }
        } catch { return .network(TranscriptNetworkFailure(error)) }
    }
}
