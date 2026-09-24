import Foundation

public enum MumlaLanguage: String, Codable, Equatable, CaseIterable, Sendable {
    case swedish = "sv"
    case english = "en"

    public var displayName: String {
        switch self {
        case .swedish: "Svenska"
        case .english: "English"
        }
    }
}

public enum LanguageMode: String, Codable, Equatable, CaseIterable, Sendable {
    case automatic = "auto"
    case swedish = "sv"
    case english = "en"
}

public enum ModelRole: String, Codable, Equatable, Sendable {
    case swedishDictation
    case englishDictation
    case languageRouting
}

public struct ModelDescriptor: Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var role: ModelRole
    public var sourceURL: URL
    public var licenseName: String
    public var attribution: String
    public var checksum: String?

    public init(
        id: String,
        displayName: String,
        role: ModelRole,
        sourceURL: URL,
        licenseName: String,
        attribution: String,
        checksum: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.sourceURL = sourceURL
        self.licenseName = licenseName
        self.attribution = attribution
        self.checksum = checksum
    }
}

public enum ModelRegistry {
    public static let pianissimo = ModelDescriptor(
        id: "KlangAI/pianissimo-sv",
        displayName: "Pianissimo Swedish",
        role: .swedishDictation,
        sourceURL: URL(string: "https://huggingface.co/KlangAI/pianissimo-sv")!,
        licenseName: "CC BY 4.0",
        attribution: "KlangAI Pianissimo, converted or quantized for Mumla."
    )

    public static let parakeetV3 = ModelDescriptor(
        id: "nvidia/parakeet-tdt-0.6b-v3",
        displayName: "NVIDIA Parakeet TDT v3",
        role: .englishDictation,
        sourceURL: URL(string: "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3")!,
        licenseName: "CC BY 4.0",
        attribution: "NVIDIA Parakeet TDT v3, converted or quantized for Mumla."
    )

    public static let fluidAudioParakeetV3CoreML = ModelDescriptor(
        id: "FluidInference/parakeet-tdt-0.6b-v3-coreml",
        displayName: "FluidAudio Parakeet TDT v3 CoreML",
        role: .languageRouting,
        sourceURL: URL(string: "https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml")!,
        licenseName: "CC BY 4.0",
        attribution: "FluidInference CoreML conversion of NVIDIA Parakeet TDT v3."
    )

    public static let communityPianissimoCoreML = ModelDescriptor(
        id: "markstrom/pianissimo-sv-coreml",
        displayName: "Community Pianissimo Swedish CoreML",
        role: .swedishDictation,
        sourceURL: URL(string: "https://huggingface.co/markstrom/pianissimo-sv-coreml")!,
        licenseName: "CC BY 4.0",
        attribution: "Community CoreML conversion of KlangAI Pianissimo. Must be verified before shipping."
    )
}
