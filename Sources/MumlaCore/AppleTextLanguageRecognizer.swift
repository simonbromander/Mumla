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
        let best = hypotheses
            .compactMap { language, confidence -> LanguageDetectionResult? in
                guard let mumlaLanguage = MumlaLanguage(naturalLanguage: language) else {
                    return nil
                }
                return LanguageDetectionResult(language: mumlaLanguage, confidence: confidence)
            }
            .max { lhs, rhs in lhs.confidence < rhs.confidence }

        return best
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
