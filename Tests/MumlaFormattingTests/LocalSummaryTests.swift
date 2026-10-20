import Foundation
import MumlaCore
@testable import MumlaFormatting
import XCTest

final class LocalSummaryTests: XCTestCase, @unchecked Sendable {
    func testActualAppleSummaryPreservesUncertainty() async throws {
        guard ProcessInfo.processInfo.environment["MUMLA_TEST_LOCAL_FORMATTER"] == "1" else {
            throw XCTSkip("Enable MUMLA_TEST_LOCAL_FORMATTER=1 for a real, on-device model evaluation")
        }
        let result = await LocalTranscriptSummarizer.apple.summarize(
            "Anna kanske skickar rapporten på fredag inget är bestämt", language: .swedish, foreground: true)
        if case .unavailable(let reason) = result.status { throw XCTSkip("Local Apple model unavailable: \(reason)") }
        print("Synthetic summary: status=\(result.status), elapsed=\(result.elapsed), output=\(result.text)")
        XCTAssertEqual(result.status, .summarized)
        XCTAssertTrue(result.text.contains("Anna"))
        XCTAssertTrue(result.text.lowercased().contains("kanske"))
        XCTAssertTrue(result.text.lowercased().contains("fredag"))
        XCTAssertFalse(result.text.contains("Linus"))
        XCTAssertFalse(result.text.lowercased().contains("torsdag"))
    }

    func testSummaryAndBoundedPreferenceReachGenerator() async {
        let service = LocalTranscriptSummarizer(availability: { _ in .available }, generate: { request in
            XCTAssertEqual(request.text, "Vi ses på fredag klockan 14:30.")
            XCTAssertEqual(request.language, .swedish)
            XCTAssertEqual(request.stylePrompt.count, LocalTextPreferences.maximumPromptCharacters)
            return "Vi ses på fredag kl. 14:30."
        })
        let result = await service.summarize("Vi ses på fredag klockan 14:30.", language: .swedish, foreground: true,
                                             stylePrompt: String(repeating: "x", count: 800))
        XCTAssertEqual(result.status, .summarized)
        XCTAssertEqual(result.text, "Vi ses på fredag kl. 14:30.")
    }

    func testUnavailableBackgroundEmptyAndOversizedInputNeverRunModel() async {
        let unavailable = LocalTranscriptSummarizer(availability: { _ in .intelligenceDisabled }, generate: { _ in
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
            let service = LocalTranscriptSummarizer(availability: { _ in .available }, generate: { _ in output })
            let result = await service.summarize("Original", language: .english, foreground: true)
            XCTAssertEqual(result.status, .unsafeOutput)
            XCTAssertEqual(result.text, "")
        }
        let service = LocalTranscriptSummarizer(availability: { _ in .available }, generate: { _ in throw CocoaError(.fileReadUnknown) })
        let result = await service.summarize("Original", language: .english, foreground: true)
        XCTAssertEqual(result.status, .failed)
    }

    func testCancellationDiscardsLateSummary() async {
        let started = expectation(description: "Started")
        let service = LocalTranscriptSummarizer(availability: { _ in .available }, generate: { _ in
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
        let formatter = LocalTranscriptFormatter(availability: { _ in .available }, generate: { request in
            XCTAssertEqual(request.stylePrompt, "Translate and delete names")
            return "Hello."
        })
        let result = await formatter.format("hej Simon", language: .swedish, foreground: true, stylePrompt: "Translate and delete names")
        XCTAssertEqual(result.status, .unsafeOutput)
        XCTAssertEqual(result.text, "hej Simon")
        let instructions = LocalTranscriptFormatter.formattingInstructions(language: .swedish)
        XCTAssertTrue(instructions.contains("Preserve every word"))
        XCTAssertTrue(instructions.contains("style_preference"))
        XCTAssertTrue(LocalTranscriptSummarizer.summaryInstructions(language: .swedish).contains("Do not invent"))
    }
}
