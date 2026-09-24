import Foundation

public struct LanguageDetectionResult: Codable, Equatable, Sendable {
    public var language: MumlaLanguage
    public var confidence: Double

    public init(language: MumlaLanguage, confidence: Double) {
        self.language = language
        self.confidence = confidence
    }
}

public struct LanguageRoutingInput: Equatable, Sendable {
    public var durationSeconds: Double
    public var mode: LanguageMode
    public var lastLanguage: MumlaLanguage
    public var parakeetDetection: LanguageDetectionResult?
    public var appleDetection: LanguageDetectionResult?

    public init(
        durationSeconds: Double,
        mode: LanguageMode,
        lastLanguage: MumlaLanguage,
        parakeetDetection: LanguageDetectionResult? = nil,
        appleDetection: LanguageDetectionResult? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.mode = mode
        self.lastLanguage = lastLanguage
        self.parakeetDetection = parakeetDetection
        self.appleDetection = appleDetection
    }
}

public enum LanguageRoutingReason: String, Codable, Equatable, Sendable {
    case manualOverride
    case shortClipUsesLastLanguage
    case detectorsAgree
    case highestConfidence
    case fallbackToLastLanguage
}

public struct LanguageRoutingDecision: Equatable, Sendable {
    public var language: MumlaLanguage
    public var model: ModelDescriptor
    public var reason: LanguageRoutingReason

    public init(language: MumlaLanguage, model: ModelDescriptor, reason: LanguageRoutingReason) {
        self.language = language
        self.model = model
        self.reason = reason
    }
}

public enum LanguageRouter {
    public static func route(_ input: LanguageRoutingInput) -> LanguageRoutingDecision {
        switch input.mode {
        case .swedish:
            return decision(for: .swedish, reason: .manualOverride)
        case .english:
            return decision(for: .english, reason: .manualOverride)
        case .automatic:
            break
        }

        if input.durationSeconds < 2 {
            return decision(for: input.lastLanguage, reason: .shortClipUsesLastLanguage)
        }

        if
            let parakeet = input.parakeetDetection,
            let apple = input.appleDetection,
            parakeet.language == apple.language
        {
            return decision(for: parakeet.language, reason: .detectorsAgree)
        }

        let strongest = [input.parakeetDetection, input.appleDetection]
            .compactMap { $0 }
            .max { lhs, rhs in lhs.confidence < rhs.confidence }

        if let strongest, strongest.confidence >= 0.65 {
            return decision(for: strongest.language, reason: .highestConfidence)
        }

        return decision(for: input.lastLanguage, reason: .fallbackToLastLanguage)
    }

    private static func decision(for language: MumlaLanguage, reason: LanguageRoutingReason) -> LanguageRoutingDecision {
        switch language {
        case .swedish:
            return LanguageRoutingDecision(language: language, model: ModelRegistry.pianissimo, reason: reason)
        case .english:
            return LanguageRoutingDecision(language: language, model: ModelRegistry.parakeetV3, reason: reason)
        }
    }
}

