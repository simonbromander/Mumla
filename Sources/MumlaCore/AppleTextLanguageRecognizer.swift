import Foundation

#if canImport(NaturalLanguage)
import NaturalLanguage

public enum AppleTextLanguageRecognizer {
    public static func detect(_ text: String, maximumHypotheses: Int = 3) -> LanguageDetectionResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)

        let hypotheses = recognizer.languageHypotheses(withMaximum: maximumHypotheses)
        // Never promote a secondary supported language over the dominant language.
        guard let dominant = recognizer.dominantLanguage,
              let language = MumlaLanguage(naturalLanguage: dominant),
              let confidence = hypotheses[dominant] else { return nil }
        return LanguageDetectionResult(language: language, confidence: confidence)
    }
}

private extension MumlaLanguage {
    init?(naturalLanguage: NLLanguage) {
        switch naturalLanguage {
        case .swedish:
            self = .swedish
        case .english:
            self = .english
        default:
            return nil
        }
    }
}
#endif
