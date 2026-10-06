import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum KeyboardSessionPhase: String, Codable, Sendable {
    case inactive, preparing, ready, recording, transcribing, result, failed
}

public struct KeyboardSessionSnapshot: Codable, Equatable, Sendable {
    public static let schema = 1
    public var version = schema
    public var sessionID: UUID?
    public var phase: KeyboardSessionPhase = .inactive
    public var heartbeat: Date = .distantPast
    public var expiresAt: Date = .distantPast
    public var recordingStartedAt: Date?
    public var requestID: UUID?
    public var acknowledgedCommandID: UUID?
    public var resultID: UUID?
    public var inputLevel: Double = 0
    public var error: String?
    public var canRetry = false
    public var appearance: String = "system"
    public var hapticsEnabled = true

    public init() {}

    public func isAlive(at now: Date = Date()) -> Bool {
        version == Self.schema && sessionID != nil && phase != .inactive && expiresAt > now &&
        now.timeIntervalSince(heartbeat) >= -1 && now.timeIntervalSince(heartbeat) < 5
    }

    public func accepts(_ command: KeyboardSessionCommand, at now: Date = Date()) -> Bool {
        guard isAlive(at: now), command.version == Self.schema,
              command.sessionID == sessionID, command.id != acknowledgedCommandID,
              now.timeIntervalSince(command.createdAt) >= -1,
              now.timeIntervalSince(command.createdAt) < 5 else { return false }
        switch command.action {
        case .start: return phase == .ready || (phase == .failed && !canRetry)
        case .stop, .cancel: return phase == .recording && requestID != nil && command.requestID == requestID
        case .retry: return phase == .failed && canRetry && requestID != nil && command.requestID == requestID
        case .consume: return phase == .result && resultID != nil && command.resultID == resultID
        case .end: return true
        }
    }
}

public struct KeyboardSessionCommand: Codable, Equatable, Sendable {
    public enum Action: String, Codable, Sendable { case start, stop, cancel, retry, consume, end }
    public var version = KeyboardSessionSnapshot.schema
    public var id: UUID
    public var sessionID: UUID
    public var action: Action
    public var createdAt: Date
    public var requestID: UUID?
    public var documentID: UUID?
    public var resultID: UUID?

    public init(id: UUID = UUID(), sessionID: UUID, action: Action, createdAt: Date = Date(),
                requestID: UUID? = nil, documentID: UUID? = nil, resultID: UUID? = nil) {
        self.id = id; self.sessionID = sessionID; self.action = action; self.createdAt = createdAt
        self.requestID = requestID; self.documentID = documentID; self.resultID = resultID
    }
}

public struct KeyboardSessionResult: Codable, Equatable, Sendable {
    public var version = KeyboardSessionSnapshot.schema
    public var id: UUID
    public var sessionID: UUID
    public var requestID: UUID
    public var documentID: UUID?
    public var text: String
    public var createdAt: Date

    public init(id: UUID, sessionID: UUID, requestID: UUID, documentID: UUID?, text: String, createdAt: Date = Date()) {
        self.id = id; self.sessionID = sessionID; self.requestID = requestID
        self.documentID = documentID; self.text = text; self.createdAt = createdAt
    }

    public func shouldAutoInsert(snapshot: KeyboardSessionSnapshot, requestID: UUID?, documentID: UUID,
                                 visible: Bool, at now: Date = Date()) -> Bool {
        visible && snapshot.isAlive(at: now) && snapshot.phase == .result &&
        snapshot.sessionID == sessionID && snapshot.resultID == id &&
        self.requestID == requestID && self.documentID == documentID &&
        now.timeIntervalSince(createdAt) >= -1 && now.timeIntervalSince(createdAt) < 90
    }
}

public enum KeyboardSessionStoreError: Error { case invalidPacket, packetTooLarge }

public final class KeyboardSessionStore: Sendable {
    public static let appGroup = "group.com.mumla.app"
    public let directory: URL
    private static let maximumBytes = 128 * 1024

    public init(directory: URL) { self.directory = directory.appendingPathComponent("KeyboardSession", isDirectory: true) }

    public static func shared() -> KeyboardSessionStore? {
        #if os(iOS)
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return nil }
        return KeyboardSessionStore(directory: url)
        #else
        return nil
        #endif
    }

    public func snapshot() throws -> KeyboardSessionSnapshot {
        guard let snapshot: KeyboardSessionSnapshot = try read("state.json") else { return .init() }
        guard snapshot.version == KeyboardSessionSnapshot.schema, snapshot.inputLevel.isFinite else { throw KeyboardSessionStoreError.invalidPacket }
        return snapshot
    }
    public func command() throws -> KeyboardSessionCommand? {
        let command: KeyboardSessionCommand? = try read("command.json")
        guard command == nil || command?.version == KeyboardSessionSnapshot.schema else { throw KeyboardSessionStoreError.invalidPacket }
        return command
    }
    public func result() throws -> KeyboardSessionResult? {
        let result: KeyboardSessionResult? = try read("result.json")
        guard result == nil || result?.version == KeyboardSessionSnapshot.schema else { throw KeyboardSessionStoreError.invalidPacket }
        return result
    }
    public func write(_ snapshot: KeyboardSessionSnapshot, notify: Bool = true) throws {
        try write(snapshot, to: "state.json")
        #if os(iOS)
        if notify { KeyboardSessionSignal.post(.state) }
        #endif
    }
    public func send(_ command: KeyboardSessionCommand) throws {
        try write(command, to: "command.json")
        #if os(iOS)
        KeyboardSessionSignal.post(.command)
        #endif
    }
    public func publish(_ result: KeyboardSessionResult) throws { try write(result, to: "result.json") }
    public func clearResult() throws {
        let url = directory.appendingPathComponent("result.json")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    // Exclusive creation makes the claim durable across extension restarts.
    public func claim(_ resultID: UUID) throws -> Bool {
        try prepareDirectory()
        let url = directory.appendingPathComponent("\(resultID.uuidString).claimed")
        let descriptor = url.path.withCString { open($0, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR) }
        guard descriptor >= 0 else {
            if errno == EEXIST { return false }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        close(descriptor)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
        return true
    }

    public func hasClaim(_ id: UUID) -> Bool { FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(id.uuidString).claimed").path) }

    public func pruneClaims() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "claimed" }
            .sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) >
                ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
        for file in files.dropFirst(100) { try FileManager.default.removeItem(at: file) }
    }

    private func read<T: Decodable>(_ name: String) throws -> T? {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= Self.maximumBytes else { throw KeyboardSessionStoreError.packetTooLarge }
        let data = try Data(contentsOf: url)
        guard data.count <= Self.maximumBytes else { throw KeyboardSessionStoreError.packetTooLarge }
        return try JSONDecoder().decode(T.self, from: data)
    }
    private func write<T: Encodable>(_ packet: T, to name: String) throws {
        let data = try JSONEncoder().encode(packet)
        guard data.count <= Self.maximumBytes else { throw KeyboardSessionStoreError.packetTooLarge }
        try prepareDirectory()
        #if os(iOS)
        try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        #endif
    }
    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        #endif
    }
}
