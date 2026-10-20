import Foundation
import MumlaCore

public struct LocalTextGenerationRequest: Equatable, Sendable {
    public let text: String
    public let language: MumlaLanguage
    public let stylePrompt: String
    public let precedingText: String

    public init(text: String, language: MumlaLanguage, stylePrompt: String, precedingText: String = "") {
        self.text = text
        #if canImport(NaturalLanguage)
        self.language = Self.resolveLanguage(text: text, fallback: language, detection: AppleTextLanguageRecognizer.detect(text))
        #else
        self.language = language
        #endif
        self.stylePrompt = LocalTextPreferences.boundedPrompt(stylePrompt)
        self.precedingText = LocalTextPreferences.boundedContext(precedingText)
    }

    static func resolveLanguage(text: String, fallback: MumlaLanguage, detection: LanguageDetectionResult?) -> MumlaLanguage {
        // Short replies and names are insufficient evidence for overriding the record.
        guard text.filter(\.isLetter).count >= 20,
              let detection, detection.confidence.isFinite,
              (0.8...1).contains(detection.confidence) else { return fallback }
        return detection.language
    }

    func prompt() throws -> String {
        // Encoding prevents user content from creating new fields or closing delimiters.
        var fields = [
            "language_hint": language.rawValue,
            "style_preference": stylePrompt,
            "transcript": text
        ]
        if !precedingText.isEmpty { fields["preceding_context"] = precedingText }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(fields), as: UTF8.self)
    }
}
