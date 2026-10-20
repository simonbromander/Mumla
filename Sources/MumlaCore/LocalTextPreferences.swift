import Foundation

public enum LocalTextPreferences {
    public static let formattingKey = "mumla.text.formattingPrompt"
    public static let summaryKey = "mumla.text.summaryPrompt"
    public static let maximumPromptCharacters = 500
    public static let maximumSummaryInputCharacters = 6_000
    public static let maximumSummaryCharacters = 1_500
    public static let maximumContextCharacters = 600
    public static let defaultFormattingPrompt = "Use sentence punctuation and short paragraphs. Preserve every word and the original language."
    public static let defaultSummaryPrompt = "Write 1–3 short bullet points. Include only stated facts. Keep uncertainty and explicit action items."

    public static func boundedPrompt(_ prompt: String) -> String {
        String(prompt.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumPromptCharacters))
    }

    public static func effectivePrompt(_ prompt: String, default defaultPrompt: String) -> String {
        let bounded = boundedPrompt(prompt)
        return bounded.isEmpty ? boundedPrompt(defaultPrompt) : bounded
    }

    public static func boundedContext(_ context: String) -> String {
        String(context.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumContextCharacters))
    }

    public static func acceptsSummary(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maximumSummaryCharacters
    }
}
