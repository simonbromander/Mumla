import Foundation

public enum MeetingTrack: String, Codable, CaseIterable, Sendable {
    case microphone, system
}

public enum MeetingCaptureState: String, Codable, Sendable {
    case recording, paused, saved, interrupted
}

public enum MeetingProcessingState: String, Codable, Sendable {
    case pending, live, processing, ready, failed
}

public struct MeetingAudioChunk: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var track: MeetingTrack
    public var start: TimeInterval
    public var duration: TimeInterval
    public var filename: String { id + ".wav" }

    public init(id: String, track: MeetingTrack, start: TimeInterval, duration: TimeInterval) {
        self.id = id; self.track = track; self.start = start; self.duration = duration
    }

    public var isValid: Bool {
        !id.isEmpty && id.count < 100 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
            && start.isFinite && start >= 0 && duration.isFinite && duration > 0 && duration <= 30
    }
}

public struct MeetingSegment: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var chunkID: String
    public var track: MeetingTrack
    public var start: TimeInterval
    public var end: TimeInterval
    public var speaker: String
    public var text: String
    public var originalText: String
    public var words: [MeetingWord]?

    public init(id: String, chunkID: String, track: MeetingTrack, start: TimeInterval,
                end: TimeInterval, speaker: String, text: String) {
        self.id = id; self.chunkID = chunkID; self.track = track; self.start = start
        self.end = end; self.speaker = speaker; self.text = text; self.originalText = text
    }
}

public struct MeetingWord: Codable, Equatable, Sendable {
    public var text: String
    public var start: Double
    public var end: Double
    public init(text: String, start: Double, end: Double) { self.text = text; self.start = start; self.end = end }
}

public enum MeetingTranscriptBoundary {
    /// Match a multi-word acoustic overlap, not arbitrary repeated words in a transcript.
    public static func committedPrefixCount(previous: [MeetingWord], incoming: [MeetingWord], boundary: Double) -> Int {
        func key(_ word: MeetingWord) -> String {
            String(word.text.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }).lowercased()
        }
        let tail = Array(previous.filter { $0.end >= boundary - 3 && $0.start < boundary }.suffix(14))
        let limit = min(tail.count, incoming.count, 14)
        guard limit >= 2 else { return 0 }
        for count in stride(from: limit, through: 2, by: -1) {
            let prior = Array(tail.suffix(count))
            let next = Array(incoming.prefix(count))
            guard prior.map(key) == next.map(key), !prior.map(key).contains(""),
                  let oldLast = prior.last, let newLast = next.last, let newFirst = next.first,
                  newFirst.start < boundary,
                  abs(oldLast.start - newLast.start) < 0.8, newLast.start < boundary + 0.4 else { continue }
            return count
        }
        return 0
    }
}

public struct MeetingRecord: Codable, Equatable, Identifiable, Sendable {
    public var schemaVersion = 1
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var sourceName: String
    public var microphoneOnly: Bool
    public var duration: TimeInterval = 0
    public var capture: MeetingCaptureState = .recording
    public var processing: MeetingProcessingState = .pending
    public var chunks: [MeetingAudioChunk] = []
    public var processedChunkIDs: Set<String> = []
    public var segments: [MeetingSegment] = []
    public var speakerNames: [String: String] = [:]
    public var audioDeleted = false
    public var completedAt: Date?
    public var deleteAudioWhenReady: Bool? = false
    public var speakerLabelsUnavailable: Bool?

    public init(id: UUID = UUID(), title: String, sourceName: String, microphoneOnly: Bool,
                createdAt: Date = Date()) {
        self.id = id; self.title = title; self.sourceName = sourceName
        self.microphoneOnly = microphoneOnly; self.createdAt = createdAt
    }

    public var orderedSegments: [MeetingSegment] {
        segments.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }

    public func speakerName(_ key: String) -> String {
        if let name = speakerNames[key], !name.isEmpty { return name }
        if key == MeetingTrack.microphone.rawValue { return microphoneOnly ? "Microphone" : "Me" }
        if key == MeetingTrack.system.rawValue { return "Them" }
        let parts = key.split(separator: "-")
        let number = parts.last.flatMap { Int($0) }.map { $0 + 1 } ?? 1
        return (key.hasPrefix("system-") ? "Remote " : "Speaker ") + String(number)
    }

    public func transcript(timestamps: Bool = true) -> String {
        orderedSegments.map { segment in
            timestamps ? "[\(Self.timestamp(segment.start))] \(speakerName(segment.speaker)): \(segment.text)" : segment.text
        }.joined(separator: timestamps ? "\n\n" : " ")
    }

    public var markdown: String {
        "# \(title.replacingOccurrences(of: "\n", with: " "))\n\n\(createdAt.formatted(.iso8601))\n\n" + transcript() + "\n"
    }

    public func exportJSON() throws -> Data {
        struct Export: Encodable {
            struct Segment: Encodable { let start: Double; let end: Double; let speaker: String; let text: String }
            let title: String; let date: Date; let duration: Double; let segments: [Segment]
        }
        let payload = Export(title: title, date: createdAt, duration: duration,
            segments: orderedSegments.map { .init(start: $0.start, end: $0.end, speaker: speakerName($0.speaker), text: $0.text) })
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    public static func timestamp(_ seconds: TimeInterval) -> String {
        let value = seconds.isFinite ? max(0, Int(min(seconds, 10_000_000))) : 0
        return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
            : String(format: "%02d:%02d", value / 60, value % 60)
    }
}

public enum MeetingStoreError: Error, LocalizedError {
    case deleted, invalidData, audioUnavailable, changed
    public var errorDescription: String? {
        switch self {
        case .deleted: "This meeting was deleted."
        case .invalidData: "The meeting data could not be verified."
        case .audioUnavailable: "The original meeting audio is no longer available."
        case .changed: "The transcript changed. Open it again before saving."
        }
    }
}

public final class MeetingStore: @unchecked Sendable {
    public let directory: URL
    private let lock = NSRecursiveLock()
    private let files = FileManager.default

    public init(directory: URL) { self.directory = directory.appendingPathComponent("Meetings", isDirectory: true) }
    public func folder(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString, isDirectory: true) }

    public func audioURL(_ chunk: MeetingAudioChunk, meetingID: UUID) throws -> URL {
        guard chunk.isValid else { throw MeetingStoreError.invalidData }
        return folder(meetingID).appendingPathComponent(chunk.filename)
    }

    @discardableResult public func create(_ meeting: MeetingRecord) throws -> MeetingRecord {
        try lock.withLock {
            guard !files.fileExists(atPath: folder(meeting.id).path), !isDeleted(meeting.id) else { throw MeetingStoreError.invalidData }
            try files.createDirectory(at: folder(meeting.id), withIntermediateDirectories: true,
                                      attributes: [.posixPermissions: 0o700])
            try write(meeting)
            return meeting
        }
    }

    public func load(_ id: UUID) throws -> MeetingRecord {
        try lock.withLock {
            guard !isDeleted(id) else { throw MeetingStoreError.deleted }
            let result = try JSONDecoder().decode(MeetingRecord.self, from: Data(contentsOf: folder(id).appendingPathComponent("meeting.json")))
            guard result.id == id, result.schemaVersion == 1, result.chunks.allSatisfy(\.isValid) else { throw MeetingStoreError.invalidData }
            return result
        }
    }

    public func list() throws -> [MeetingRecord] {
        try lock.withLock {
            guard files.fileExists(atPath: directory.path) else { return [] }
            return try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).compactMap { url in
                guard let id = UUID(uuidString: url.lastPathComponent), !isDeleted(id) else { return nil }
                return try? load(id)
            }.sorted { $0.createdAt > $1.createdAt }
        }
    }

    @discardableResult public func update(_ id: UUID, _ change: (inout MeetingRecord) throws -> Void) throws -> MeetingRecord {
        try lock.withLock {
            var meeting = try load(id)
            try change(&meeting)
            guard meeting.id == id, meeting.duration.isFinite, meeting.duration >= 0,
                  meeting.chunks.allSatisfy(\.isValid) else { throw MeetingStoreError.invalidData }
            try write(meeting)
            return meeting
        }
    }

    public func appendChunk(_ chunk: MeetingAudioChunk, meetingID: UUID) throws {
        try lock.withLock {
            let audio = try audioURL(chunk, meetingID: meetingID)
            guard files.fileExists(atPath: audio.path) else { throw MeetingStoreError.audioUnavailable }
            _ = try update(meetingID) {
                guard !$0.audioDeleted, !$0.chunks.contains(where: { $0.id == chunk.id }) else { throw MeetingStoreError.invalidData }
                $0.chunks.append(chunk); $0.duration = max($0.duration, chunk.start + chunk.duration)
            }
        }
    }

    public func commitTranscript(_ segments: [MeetingSegment], chunkID: String, meetingID: UUID) throws {
        _ = try update(meetingID) { meeting in
            guard meeting.chunks.contains(where: { $0.id == chunkID }) else { throw MeetingStoreError.invalidData }
            guard !meeting.processedChunkIDs.contains(chunkID) else { return }
            guard segments.allSatisfy({ $0.chunkID == chunkID && $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end >= $0.start }) else { throw MeetingStoreError.invalidData }
            meeting.segments.append(contentsOf: segments)
            meeting.processedChunkIDs.insert(chunkID)
        }
    }

    public func correct(_ segmentID: String, meetingID: UUID, expectedText: String, text: String) throws {
        _ = try update(meetingID) { meeting in
            guard let index = meeting.segments.firstIndex(where: { $0.id == segmentID }),
                  meeting.segments[index].text == expectedText, text.count <= 20_000 else { throw MeetingStoreError.changed }
            meeting.segments[index].text = text
        }
    }

    public func recover() throws {
        for record in try list() {
            if !record.audioDeleted {
                let descriptors = try files.contentsOfDirectory(at: folder(record.id), includingPropertiesForKeys: nil)
                    .filter { $0.lastPathComponent.hasSuffix(".wav.json") }
                for url in descriptors {
                    guard let chunk = try? JSONDecoder().decode(MeetingAudioChunk.self, from: Data(contentsOf: url)),
                          chunk.isValid, !record.chunks.contains(where: { $0.id == chunk.id }) else { continue }
                    try appendChunk(chunk, meetingID: record.id)
                }
            }
            if record.capture == .recording || record.capture == .paused {
                _ = try update(record.id) { $0.capture = .interrupted; $0.processing = .pending }
            } else if record.processing == .processing || record.processing == .live {
                _ = try update(record.id) { $0.processing = .pending }
            }
        }
    }

    public func deleteAudio(_ id: UUID) throws {
        try lock.withLock {
            let record = try load(id)
            guard record.capture != .recording && record.capture != .paused else { throw MeetingStoreError.changed }
            // Persist the privacy decision before deleting; an interrupted cleanup can be retried.
            _ = try update(id) { $0.audioDeleted = true }
            for chunk in record.chunks {
                let url = try audioURL(chunk, meetingID: id)
                if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
            }
        }
    }

    public func pruneAudio(now: Date = Date()) throws {
        for record in try list() where record.audioDeleted || (record.completedAt.map { now.timeIntervalSince($0) >= 7 * 86400 } ?? false) {
            if record.capture != .recording && record.capture != .paused { try deleteAudio(record.id) }
        }
    }

    public func delete(_ id: UUID) throws {
        try lock.withLock {
            try files.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data().write(to: directory.appendingPathComponent(id.uuidString + ".deleted"), options: .atomic)
            if files.fileExists(atPath: folder(id).path) { try files.removeItem(at: folder(id)) }
        }
    }

    private func isDeleted(_ id: UUID) -> Bool { files.fileExists(atPath: directory.appendingPathComponent(id.uuidString + ".deleted").path) }
    private func write(_ record: MeetingRecord) throws {
        guard !isDeleted(record.id) else { throw MeetingStoreError.deleted }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let url = folder(record.id).appendingPathComponent("meeting.json")
        try encoder.encode(record).write(to: url, options: .atomic)
        try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
