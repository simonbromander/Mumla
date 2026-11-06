import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var languageMode: LanguageMode
    public var lastLanguage: MumlaLanguage
    public var soundFeedbackEnabled: Bool
    public var launchAtLogin: Bool
    public var onboardingCompleted: Bool
    public var triggerKey: DictationTriggerKey
    public var showPasteDialog: Bool
    public var formatDictationBeforePasting: Bool
    public var textModelProvider: TextModelProvider
    public var dictationOverlayStyle: DictationOverlayStyle
    public var djiMicButtonEnabled: Bool
    /// When set, dictation records from this input device instead of following the system default.
    public var pinnedInputDevice: PinnedInputDevice?

    public init(
        languageMode: LanguageMode = .automatic,
        lastLanguage: MumlaLanguage = .swedish,
        soundFeedbackEnabled: Bool = true,
        launchAtLogin: Bool = false,
        onboardingCompleted: Bool = false,
        triggerKey: DictationTriggerKey = .control,
        showPasteDialog: Bool = true,
        pinnedInputDevice: PinnedInputDevice? = nil,
        djiMicButtonEnabled: Bool = false,
        formatDictationBeforePasting: Bool = false,
        dictationOverlayStyle: DictationOverlayStyle = .recorder,
        textModelProvider: TextModelProvider = .qwen
    ) {
        self.languageMode = languageMode
        self.lastLanguage = lastLanguage
        self.soundFeedbackEnabled = soundFeedbackEnabled
        self.launchAtLogin = launchAtLogin
        self.onboardingCompleted = onboardingCompleted
        self.triggerKey = triggerKey
        self.showPasteDialog = showPasteDialog
        self.pinnedInputDevice = pinnedInputDevice
        self.djiMicButtonEnabled = djiMicButtonEnabled
        self.formatDictationBeforePasting = formatDictationBeforePasting
        self.dictationOverlayStyle = dictationOverlayStyle
        self.textModelProvider = textModelProvider
    }

    public static let `default` = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case languageMode
        case lastLanguage
        case soundFeedbackEnabled
        case launchAtLogin
        case onboardingCompleted
        case triggerKey
        case showPasteDialog
        case pinnedInputDevice
        case djiMicButtonEnabled
        case formatDictationBeforePasting
        case dictationOverlayStyle
        case textModelProvider
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        languageMode = try container.decodeIfPresent(LanguageMode.self, forKey: .languageMode) ?? .automatic
        lastLanguage = try container.decodeIfPresent(MumlaLanguage.self, forKey: .lastLanguage) ?? .swedish
        soundFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundFeedbackEnabled) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        triggerKey = try container.decodeIfPresent(DictationTriggerKey.self, forKey: .triggerKey) ?? .control
        showPasteDialog = try container.decodeIfPresent(Bool.self, forKey: .showPasteDialog) ?? true
        pinnedInputDevice = try container.decodeIfPresent(PinnedInputDevice.self, forKey: .pinnedInputDevice)
        djiMicButtonEnabled = try container.decodeIfPresent(Bool.self, forKey: .djiMicButtonEnabled) ?? false
        formatDictationBeforePasting = try container.decodeIfPresent(Bool.self, forKey: .formatDictationBeforePasting) ?? false
        dictationOverlayStyle = try container.decodeIfPresent(DictationOverlayStyle.self, forKey: .dictationOverlayStyle) ?? .recorder
        textModelProvider = try container.decodeIfPresent(TextModelProvider.self, forKey: .textModelProvider) ?? .qwen
    }
}

public enum DictationOverlayStyle: String, Codable, CaseIterable, Sendable {
    case recorder, minimal
}

public enum TextModelProvider: String, Codable, CaseIterable, Sendable {
    case qwen, appleIntelligence

    public var displayName: String {
        self == .qwen ? "Qwen3.5 4B" : "Apple Intelligence"
    }
}

public struct PinnedInputDevice: Codable, Equatable, Sendable {
    /// Core Audio device UID, stable across reconnects and restarts.
    public var uid: String
    /// Last known display name, shown while the device is disconnected.
    public var name: String

    public init(uid: String, name: String) {
        self.uid = uid
        self.name = name
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
