import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var languageMode: LanguageMode
    public var lastLanguage: MumlaLanguage
    public var soundFeedbackEnabled: Bool
    public var launchAtLogin: Bool
    public var onboardingCompleted: Bool
    public var triggerKey: DictationTriggerKey

    public init(
        languageMode: LanguageMode = .automatic,
        lastLanguage: MumlaLanguage = .swedish,
        soundFeedbackEnabled: Bool = true,
        launchAtLogin: Bool = false,
        onboardingCompleted: Bool = false,
        triggerKey: DictationTriggerKey = .control
    ) {
        self.languageMode = languageMode
        self.lastLanguage = lastLanguage
        self.soundFeedbackEnabled = soundFeedbackEnabled
        self.launchAtLogin = launchAtLogin
        self.onboardingCompleted = onboardingCompleted
        self.triggerKey = triggerKey
    }

    public static let `default` = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case languageMode
        case lastLanguage
        case soundFeedbackEnabled
        case launchAtLogin
        case onboardingCompleted
        case triggerKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        languageMode = try container.decodeIfPresent(LanguageMode.self, forKey: .languageMode) ?? .automatic
        lastLanguage = try container.decodeIfPresent(MumlaLanguage.self, forKey: .lastLanguage) ?? .swedish
        soundFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundFeedbackEnabled) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        triggerKey = try container.decodeIfPresent(DictationTriggerKey.self, forKey: .triggerKey) ?? .control
    }
}

public final class AppSettingsStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("settings.json")
    }

    public static func defaultStore(fileManager: FileManager = .default) -> AppSettingsStore {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return AppSettingsStore(directory: base.appendingPathComponent("Mumla", isDirectory: true))
    }

    public func load() throws -> AppSettings {
        try lock.withLock {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return .default
            }
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(AppSettings.self, from: data)
        }
    }

    public func save(_ settings: AppSettings) throws {
        try lock.withLock {
            let data = try JSONEncoder.prettySettings.encode(settings)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        }
    }
}

private extension JSONEncoder {
    static var prettySettings: JSONEncoder {
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
