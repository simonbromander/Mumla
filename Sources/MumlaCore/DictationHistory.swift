import Foundation

public struct DictationRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var text: String
    public var language: MumlaLanguage
    public var durationMilliseconds: Double?

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

    public func clear() throws {
        try lock.withLock {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
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
