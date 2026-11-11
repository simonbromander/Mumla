import Combine
import Foundation
import MumlaCore

@MainActor
public final class TranscriptDestinationController: ObservableObject {
    @Published public private(set) var destination: TranscriptDestination?
    @Published public private(set) var isSending = false { didSet { activityChanged?() } }
    @Published public private(set) var settingsStatus: String?
    @Published public private(set) var results: [UUID: String] = [:]
    private var receipts: Set<UUID> = []
    private let settings: AppSettingsStore
    private let tokens: any DestinationTokenStoring
    private let sender: TranscriptSender
    public var settingsChanged: ((AppSettings) -> Void)?
    public var activityChanged: (() -> Void)?

    public init(settings: AppSettingsStore, tokens: any DestinationTokenStoring = DestinationTokenStore(),
                client: any TranscriptHTTPClient = URLSessionTranscriptClient()) {
        self.settings = settings; self.tokens = tokens
        sender = TranscriptSender(client: client, tokens: tokens)
        destination = (try? settings.load())?.transcriptDestination
    }

    public func save(name: String, address: String, token: String) -> Bool {
        guard !isSending else { return false }
        do {
            guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw TranscriptDestinationError.invalidAddress
            }
            let next = try TranscriptDestination(name: name, url: url)
            let previous = destination
            let oldToken = try previous.flatMap { try tokens.read(for: $0.url) }
            let replacedToken = try tokens.read(for: url)
            // A different endpoint always needs explicit new credentials, never the old token.
            let value = token.isEmpty && previous?.url == url ? oldToken : token
            guard let value, DestinationTokenStore.accepts(value) else { throw DestinationTokenError.invalidValue }
            do {
                try tokens.save(value, for: url)
                if let previous, previous.url != url { try tokens.delete(for: previous.url) }
                let saved = try settings.setTranscriptDestination(next)
                destination = next; settingsChanged?(saved)
                settingsStatus = mText("Sparat. Inget skickades.", "Saved. Nothing was sent.")
                return true
            } catch {
                do {
                    if let replacedToken { try tokens.save(replacedToken, for: url) } else { try tokens.delete(for: url) }
                    if let previous, previous.url != url, let oldToken { try tokens.save(oldToken, for: previous.url) }
                } catch {
                    settingsStatus = mText("Kunde inte återställa nyckelringen. Ange token igen innan du skickar.",
                                           "Could not restore the Keychain. Enter the token again before sending.")
                    return false
                }
                throw error
            }
        } catch {
            if error is TranscriptDestinationError {
                settingsStatus = mText("Ange ett namn och en HTTPS-adress utan inloggning eller fragment.",
                                       "Enter a name and an HTTPS address without embedded credentials or a fragment.")
            } else if error as? DestinationTokenError == .invalidValue {
                settingsStatus = mText("Ange en giltig token för den här adressen.", "Enter a valid token for this address.")
            } else {
                settingsStatus = mText("Kunde inte spara destinationen eller nyckelringen.", "Could not save the destination or Keychain.")
            }
            return false
        }
    }

    public func remove() {
        guard !isSending, let previous = destination else { return }
        do {
            let token = try tokens.read(for: previous.url)
            try tokens.delete(for: previous.url)
            do {
                let saved = try settings.setTranscriptDestination(nil)
                destination = nil; settingsChanged?(saved)
                settingsStatus = mText("Destination och token borttagna.", "Destination and token removed.")
            } catch {
                if let token { try tokens.save(token, for: previous.url) }
                throw error
            }
        } catch {
            settingsStatus = mText("Borttagningen misslyckades. Kontrollera nyckelringen och försök igen.",
                                   "Removal failed. Check the Keychain and try again.")
        }
    }

    public func wasSent(_ id: UUID, sentAt: Date?) -> Bool { sentAt != nil || receipts.contains(id) }

    public func test() async {
        guard !isSending, let destination else { return }
        isSending = true; settingsStatus = mText("Skickar test…", "Sending test…")
        defer { isSending = false }
        guard let sample = try? OutgoingTranscript(text: "Mumla test transcript.", language: .english,
                                                  recordedAt: Date(), durationSeconds: 0, version: Self.version) else { return }
        settingsStatus = Self.message(await sender.send(sample, to: destination))
    }

    @discardableResult
    public func send(_ transcript: OutgoingTranscript, id: UUID, approvedDestination: TranscriptDestination,
                     persistReceipt: (Date) throws -> Void) async -> TranscriptSendResult? {
        guard !isSending, destination == approvedDestination else { return nil }
        isSending = true; results[id] = mText("Skickar…", "Sending…")
        defer { isSending = false }
        let result = await sender.send(transcript, to: approvedDestination)
        results[id] = Self.message(result)
        if case .sent = result {
            receipts.insert(id)
            do { try persistReceipt(Date()) }
            catch {
                results[id] = mText("Skickat. Kunde inte spara sändningsdatumet lokalt. Skicka inte igen.",
                                    "Sent. Could not save the send date locally. Do not send again.")
            }
        }
        return result
    }

    public static var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.1" }

    #if DEBUG
    /// Isolated UI fixtures never use the production Keychain or a network connection.
    public static func uiFixture(settings: AppSettingsStore, configured: Bool) -> TranscriptDestinationController {
        let tokens = DestinationFixtureTokens()
        if configured {
            var parts = URLComponents(); parts.scheme = "https"; parts.host = "receiver.invalid"
            if let url = parts.url, let destination = try? TranscriptDestination(name: "Test destination", url: url) {
                try? tokens.save(UUID().uuidString, for: url)
                try? settings.setTranscriptDestination(destination)
            }
        }
        return TranscriptDestinationController(settings: settings, tokens: tokens, client: DestinationFixtureClient())
    }
    #endif

    public static func message(_ result: TranscriptSendResult) -> String {
        switch result {
        case .sent: return mText("Skickat", "Sent")
        case .unauthorized: return mText("Token nekades (401).", "Token was refused (401).")
        case .rejected(let code): return mText("Mottagaren nekade begäran", "Receiver rejected the request") + " (\(code))."
        case .notConfigured: return mText("Spara destination och token i Inställningar.", "Save a destination and token in Settings.")
        case .network(.timeout): return mText("Tidsgränsen nåddes. Mottagaren kan ha fått texten. Kontrollera innan du skickar igen.",
                                             "Timed out. The receiver may have the text. Check before sending again.")
        case .network(.offline): return mText("Ingen internetanslutning. Inget nytt försök görs.", "No internet connection. No retry will be made.")
        case .network(.secureConnection): return mText("Säker anslutning misslyckades. Kontrollera serverns certifikat.", "Secure connection failed. Check the server certificate.")
        case .network: return mText("Anslutningen avbröts. Kontrollera mottagaren innan du skickar igen.", "Connection interrupted. Check the receiver before sending again.")
        }
    }
}

#if DEBUG
private final class DestinationFixtureTokens: DestinationTokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [URL: String] = [:]
    func save(_ token: String, for url: URL) throws { lock.withLock { values[url] = token } }
    func read(for url: URL) throws -> String? { lock.withLock { values[url] } }
    func delete(for url: URL) throws { _ = lock.withLock { values.removeValue(forKey: url) } }
}
private struct DestinationFixtureClient: TranscriptHTTPClient {
    func post(_ request: URLRequest) async throws -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
    }
}
#endif
