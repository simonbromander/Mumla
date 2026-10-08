import Foundation

public enum LocalTextPreferences {
    public static let formattingKey = "mumla.text.formattingPrompt"
    public static let summaryKey = "mumla.text.summaryPrompt"
    public static let maximumPromptCharacters = 500
    public static let maximumSummaryInputCharacters = 6_000
    public static let maximumSummaryCharacters = 1_500

    public static func boundedPrompt(_ prompt: String) -> String {
        String(prompt.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumPromptCharacters))
    }

    public static func acceptsSummary(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maximumSummaryCharacters
    }
}
