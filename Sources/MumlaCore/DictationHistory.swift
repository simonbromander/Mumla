import Foundation

public struct DictationRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var text: String
    public var language: MumlaLanguage
    public var durationMilliseconds: Double?
    public var originalText: String?

    public var compactPreview: String {
        let words = text.split(whereSeparator: \.isWhitespace)
        return words.prefix(3).joined(separator: " ") + (words.count > 3 ? "…" : "")
    }

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        text: String,
        language: MumlaLanguage,
        durationMilliseconds: Double? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.language = language
        self.durationMilliseconds = durationMilliseconds
        self.originalText = nil
    }
}

public struct DictionaryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var original: String
    public var replacement: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        original: String,
        replacement: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.original = original
        self.replacement = replacement
        self.createdAt = createdAt
    }
}

public final class DictationHistoryStore: @unchecked Sendable {
    private let fileURL: URL
    private let limit: Int
    private let lock = NSLock()

    public init(directory: URL, limit: Int = 100) {
        self.fileURL = directory.appendingPathComponent("history.json")
        self.limit = limit
    }

    public static func defaultStore(fileManager: FileManager = .default) -> DictationHistoryStore {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return DictationHistoryStore(directory: base.appendingPathComponent("Mumla", isDirectory: true))
    }

    public func load() throws -> [DictationRecord] {
        try lock.withLock {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return []
            }
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([DictationRecord].self, from: data)
        }
    }

    @discardableResult
    public func append(_ record: DictationRecord) throws -> [DictationRecord] {
        try lock.withLock {
            var records: [DictationRecord]
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                records = try JSONDecoder().decode([DictationRecord].self, from: data)
            } else {
                records = []
            }

            records.insert(record, at: 0)
            if records.count > limit {
                records = Array(records.prefix(limit))
            }

            let data = try JSONEncoder.prettyMumla.encode(records)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            return records
        }
    }

    public func correctWord(
        _ selection: TranscriptWordSelection,
        replacement: String,
        dictionary: DictionaryStore
    ) throws -> (history: [DictationRecord], dictionary: [DictionaryEntry]) {
        try lock.withLock {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw TranscriptCorrectionError.transcriptChanged
            }
            var records = try JSONDecoder().decode([DictationRecord].self, from: Data(contentsOf: fileURL))
            guard let index = records.firstIndex(where: { $0.id == selection.recordID }),
                  records[index].text == selection.text else {
                throw TranscriptCorrectionError.transcriptChanged
            }
            records[index].text = try selection.replacing(with: replacement)
            let data = try JSONEncoder.prettyMumla.encode(records)
            let previousDictionary = try dictionary.load()
            let entries = try dictionary.add(original: selection.original, replacement: replacement)
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                // Each file is atomic; restore the wordlist if the history write fails.
                do { try dictionary.replaceAll(previousDictionary) }
                catch { throw TranscriptCorrectionError.dictionaryRollbackFailed }
                throw error
            }
            return (records, entries)
        }
    }

    @discardableResult
    public func applyFormatting(recordID: UUID, expectedText: String, formattedText: String) throws -> [DictationRecord] {
        try lock.withLock {
            var records = try JSONDecoder().decode([DictationRecord].self, from: Data(contentsOf: fileURL))
            guard let index = records.firstIndex(where: { $0.id == recordID }),
                  records[index].text == expectedText,
                  TranscriptFormattingPolicy.accepts(original: expectedText, formatted: formattedText) else {
                throw TranscriptCorrectionError.transcriptChanged
            }
            if records[index].originalText == nil { records[index].originalText = expectedText }
            records[index].text = formattedText
            try JSONEncoder.prettyMumla.encode(records).write(to: fileURL, options: .atomic)
            return records
        }
    }

    @discardableResult
    public func restoreOriginal(recordID: UUID, expectedText: String) throws -> [DictationRecord] {
        try lock.withLock {
            var records = try JSONDecoder().decode([DictationRecord].self, from: Data(contentsOf: fileURL))
            guard let index = records.firstIndex(where: { $0.id == recordID }),
                  records[index].text == expectedText, let original = records[index].originalText else {
                throw TranscriptCorrectionError.transcriptChanged
            }
            records[index].text = original
            records[index].originalText = nil
            try JSONEncoder.prettyMumla.encode(records).write(to: fileURL, options: .atomic)
            return records
        }
    }

    public func clear() throws {
        try lock.withLock {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}

public final class DictionaryStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("dictionary.json")
    }

    public static func defaultStore(fileManager: FileManager = .default) -> DictionaryStore {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return DictionaryStore(directory: base.appendingPathComponent("Mumla", isDirectory: true))
    }

    public func load() throws -> [DictionaryEntry] {
        try lock.withLock {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return []
            }
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([DictionaryEntry].self, from: data)
        }
    }

    @discardableResult
    public func add(original: String, replacement: String) throws -> [DictionaryEntry] {
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty, !trimmedReplacement.isEmpty else {
            return try load()
        }

        return try lock.withLock {
            var entries = try loadWithoutLock()
            entries.removeAll {
                $0.original.caseInsensitiveCompare(trimmedOriginal) == .orderedSame
            }
            entries.insert(
                DictionaryEntry(original: trimmedOriginal, replacement: trimmedReplacement),
                at: 0
            )
            try saveWithoutLock(entries)
            return entries
        }
    }

    @discardableResult
    public func delete(id: UUID) throws -> [DictionaryEntry] {
        try lock.withLock {
            var entries = try loadWithoutLock()
            entries.removeAll { $0.id == id }
            try saveWithoutLock(entries)
            return entries
        }
    }

    public func replaceAll(_ entries: [DictionaryEntry]) throws {
        try lock.withLock {
            try saveWithoutLock(entries)
        }
    }

    private func loadWithoutLock() throws -> [DictionaryEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([DictionaryEntry].self, from: data)
    }

    private func saveWithoutLock(_ entries: [DictionaryEntry]) throws {
        let data = try JSONEncoder.prettyMumla.encode(entries)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var prettyMumla: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) throws -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
