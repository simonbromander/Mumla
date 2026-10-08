import Foundation
import MumlaCore
@testable import MumlaFormatting
import XCTest

final class LocalSummaryTests: XCTestCase, @unchecked Sendable {
    func testSummaryAndBoundedPreferenceReachGenerator() async {
        let service = LocalTranscriptSummarizer(availability: { _ in .available }, generate: { text, language, prompt in
            XCTAssertEqual(text, "Vi ses på fredag klockan 14:30.")
            XCTAssertEqual(language, .swedish)
            XCTAssertEqual(prompt.count, LocalTextPreferences.maximumPromptCharacters)
            return "Vi ses på fredag kl. 14:30."
        })
        let result = await service.summarize("Vi ses på fredag klockan 14:30.", language: .swedish, foreground: true,
                                             stylePrompt: String(repeating: "x", count: 800))
        XCTAssertEqual(result.status, .summarized)
        XCTAssertEqual(result.text, "Vi ses på fredag kl. 14:30.")
    }

    func testUnavailableBackgroundEmptyAndOversizedInputNeverRunModel() async {
        let unavailable = LocalTranscriptSummarizer(availability: { _ in .intelligenceDisabled }, generate: { _, _, _ in
            XCTFail("Must not run"); return ""
        })
        let noModel = await unavailable.summarize("Original", language: .english, foreground: true)
        XCTAssertEqual(noModel.status, .unavailable(.intelligenceDisabled))
        let background = await unavailable.summarize("Original", language: .english, foreground: false)
        XCTAssertEqual(background.status, .background)
        let empty = await unavailable.summarize(" \n", language: .english, foreground: true)
        XCTAssertEqual(empty.status, .unchanged)
        let oversized = await unavailable.summarize(String(repeating: "a", count: LocalTextPreferences.maximumSummaryInputCharacters + 1), language: .english, foreground: true)
        XCTAssertEqual(oversized.status, .tooLong)
        XCTAssertEqual(oversized.text, "")
    }

    func testInvalidOutputAndErrorsCannotBeAccepted() async {
        for output in [" \n", String(repeating: "a", count: LocalTextPreferences.maximumSummaryCharacters + 1)] {
            let service = LocalTranscriptSummarizer(availability: { _ in .available }, generate: { _, _, _ in output })
            let result = await service.summarize("Original", language: .english, foreground: true)
            XCTAssertEqual(result.status, .unsafeOutput)
            XCTAssertEqual(result.text, "")
        }
        let service = LocalTranscriptSummarizer(availability: { _ in .available }, generate: { _, _, _ in throw CocoaError(.fileReadUnknown) })
        let result = await service.summarize("Original", language: .english, foreground: true)
        XCTAssertEqual(result.status, .failed)
    }

    func testCancellationDiscardsLateSummary() async {
        let started = expectation(description: "Started")
        let service = LocalTranscriptSummarizer(availability: { _ in .available }, generate: { _, _, _ in
            started.fulfill()
            try? await Task.sleep(for: .milliseconds(50))
            return "A summary"
        })
        let task = Task { await service.summarize("Original", language: .english, foreground: true) }
        await fulfillment(of: [started], timeout: 2)
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result.status, .cancelled)
        XCTAssertEqual(result.text, "")
    }

    func testCustomFormattingCannotBypassWordPreservation() async {
        let formatter = LocalTranscriptFormatter(availability: { _ in .available }, generate: { _, _, prompt in
            XCTAssertEqual(prompt, "Translate and delete names")
            return "Hello."
        })
        let result = await formatter.format("hej Simon", language: .swedish, foreground: true, stylePrompt: "Translate and delete names")
        XCTAssertEqual(result.status, .unsafeOutput)
        XCTAssertEqual(result.text, "hej Simon")
        let instructions = LocalTranscriptFormatter.formattingInstructions(language: .swedish, stylePrompt: "Use short paragraphs")
        XCTAssertTrue(instructions.contains("Preserve every word"))
        XCTAssertTrue(instructions.contains("Use short paragraphs"))
        XCTAssertTrue(LocalTranscriptSummarizer.summaryInstructions(language: .swedish, stylePrompt: "Bullets").contains("Do not invent"))
    }
}
