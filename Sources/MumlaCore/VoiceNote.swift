import CryptoKit
import Foundation

/// An immutable recording identity. Transcription and delivery state remain separate.
public struct VoiceNote: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let duration: TimeInterval
    public let language: String
    public let audioSHA256: String
    public let audioByteCount: Int
    public var transcript: String?
    public var delivered: Bool

    public init(id: UUID = UUID(), createdAt: Date = Date(), duration: TimeInterval,
                language: String, audioSHA256: String, audioByteCount: Int,
                transcript: String? = nil, delivered: Bool = false) {
        self.id = id; self.createdAt = createdAt; self.duration = duration
        self.language = language; self.audioSHA256 = audioSHA256; self.audioByteCount = audioByteCount
        self.transcript = transcript; self.delivered = delivered
    }

    public func validate(requireTranscript: Bool = false) throws {
        guard duration.isFinite, duration > 0, duration <= 61,
              ["sv", "en"].contains(language), audioByteCount > 44, audioByteCount <= 2_000_000,
              audioSHA256.count == 64, audioSHA256.allSatisfy({ "0123456789abcdef".contains($0) }),
              createdAt.timeIntervalSince1970.isFinite,
              (transcript?.utf8.count ?? 0) <= 24_000 else { throw VoiceNoteError.invalidNote }
        if requireTranscript && (transcript?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            throw VoiceNoteError.invalidNote
        }
    }

    /// The acknowledgement covers the transcript as well as the recording.
    public func transferData() throws -> Data {
        try validate(requireTranscript: true)
        var copy = self
        copy.delivered = false
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(copy)
        guard data.count <= 32_000 else { throw VoiceNoteError.invalidNote }
        return data
    }

    public var deliveryID: String? {
        guard let data = try? transferData() else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public enum VoiceNoteError: Error, LocalizedError {
    case invalidNote, invalidAudio, conflict, deleted
    public var errorDescription: String? {
        switch self {
        case .invalidNote: "The voice note is incomplete or exceeds the recording limit."
        case .invalidAudio: "The recording could not be verified. The original remains on the Watch."
        case .conflict: "A different recording already uses this note identifier."
        case .deleted: "This voice note was deleted."
        }
    }
}

/// Each note commits its audio before its metadata. A deletion marker prevents redelivery from restoring a deleted note.
public final class VoiceNoteStore: @unchecked Sendable {
    public let directory: URL
    private let lock = NSRecursiveLock()
    private let files = FileManager.default

    public init(directory: URL) { self.directory = directory }

    public static func defaultStore() -> VoiceNoteStore {
        VoiceNoteStore(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mumla/VoiceNotes", isDirectory: true))
    }

    public func audioURL(for id: UUID) -> URL { folder(id).appendingPathComponent("audio.wav") }

    public func load() throws -> [VoiceNote] {
        lock.lock(); defer { lock.unlock() }
        guard files.fileExists(atPath: directory.path) else { return [] }
        return try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).compactMap { url in
            guard let id = UUID(uuidString: url.lastPathComponent), !isDeleted(id) else { return nil }
            guard files.fileExists(atPath: url.appendingPathComponent("note.json").path) else { return nil }
            let data = try Data(contentsOf: url.appendingPathComponent("note.json"))
            let note = try JSONDecoder().decode(VoiceNote.self, from: data)
            try note.validate()
            guard note.id == id, files.fileExists(atPath: audioURL(for: id).path) else { throw VoiceNoteError.invalidAudio }
            return note
        }.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    public func saveRecording(from audio: URL, id: UUID = UUID(), createdAt: Date = Date(),
                              duration: TimeInterval, language: String) throws -> VoiceNote {
        let size = try audioSize(at: audio)
        guard size > 44, size <= 2_000_000 else { throw VoiceNoteError.invalidAudio }
        let note = VoiceNote(id: id, createdAt: createdAt, duration: duration, language: language,
                             audioSHA256: try ModelArtifactVerifier.sha256Hex(of: audio), audioByteCount: size)
        try importNote(note, audio: audio)
        return note
    }

    /// Call synchronously from WCSession's file callback, before its temporary file disappears.
    public func receive(_ data: Data, audio: URL, deliveryID: String) throws -> VoiceNote {
        guard data.count <= 32_000 else { throw VoiceNoteError.invalidNote }
        let note = try JSONDecoder().decode(VoiceNote.self, from: data)
        try note.validate(requireTranscript: true)
        guard note.deliveryID == deliveryID else { throw VoiceNoteError.invalidNote }
        try importNote(note, audio: audio)
        return note
    }

    public func importNote(_ note: VoiceNote, audio: URL) throws {
        lock.lock(); defer { lock.unlock() }
        try note.validate()
        guard !isDeleted(note.id) else { throw VoiceNoteError.deleted }
        let size = try audioSize(at: audio)
        guard size == note.audioByteCount,
              try ModelArtifactVerifier.sha256Hex(of: audio) == note.audioSHA256 else { throw VoiceNoteError.invalidAudio }
        if let old = try read(note.id) {
            guard old.audioSHA256 == note.audioSHA256, old.createdAt == note.createdAt,
                  old.language == note.language, old.duration == note.duration,
                  old.transcript == note.transcript else { throw VoiceNoteError.conflict }
            return
        }
        try files.createDirectory(at: folder(note.id), withIntermediateDirectories: true)
        let destination = audioURL(for: note.id)
        // A previous interrupted commit can leave audio without metadata.
        if files.fileExists(atPath: destination.path) { try files.removeItem(at: destination) }
        try files.copyItem(at: audio, to: destination)
        guard try audioSize(at: destination) == note.audioByteCount,
              try ModelArtifactVerifier.sha256Hex(of: destination) == note.audioSHA256 else {
            throw VoiceNoteError.invalidAudio
        }
        try protect(destination)
        try write(note)
    }

    public func setTranscript(_ text: String, for id: UUID) throws {
        lock.lock(); defer { lock.unlock() }
        guard var note = try read(id), !isDeleted(id) else { throw VoiceNoteError.deleted }
        note.transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
        note.delivered = false
        try note.validate(requireTranscript: true)
        try write(note)
    }

    public func acknowledge(id: UUID, deliveryID: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard var note = try read(id), note.deliveryID == deliveryID, !isDeleted(id) else { return }
        note.delivered = true
        try write(note)
    }

    public func delete(id: UUID) throws {
        lock.lock(); defer { lock.unlock() }
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: tombstone(id), options: .atomic)
        if files.fileExists(atPath: folder(id).path) { try files.removeItem(at: folder(id)) }
    }

    public func isDeleted(_ id: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return files.fileExists(atPath: tombstone(id).path)
    }

    private func folder(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString, isDirectory: true) }
    private func tombstone(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).deleted") }
    private func read(_ id: UUID) throws -> VoiceNote? {
        let url = folder(id).appendingPathComponent("note.json")
        guard files.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(VoiceNote.self, from: Data(contentsOf: url))
    }
    private func write(_ note: VoiceNote) throws {
        let url = folder(note.id).appendingPathComponent("note.json")
        try JSONEncoder().encode(note).write(to: url, options: .atomic)
        try protect(url)
    }
    private func protect(_ url: URL) throws {
        #if os(iOS) || os(watchOS)
        try files.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        #endif
    }
    private func audioSize(at url: URL) throws -> Int {
        // URL resource values can retain a stale size when a capture path is reused.
        let attributes = try files.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber else { throw VoiceNoteError.invalidAudio }
        return size.intValue
    }
}
