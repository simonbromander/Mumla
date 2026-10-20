import Foundation
import MumlaCore
import XCTest
@testable import MumlaWatch

final class WatchTranscriberTests: XCTestCase {
    func testModelManifestPinsEveryDownload() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "WatchModel", withExtension: "json"))
        let files = try JSONDecoder().decode([WatchModelFile].self, from: Data(contentsOf: url))
        XCTAssertEqual(files.count, 22)
        XCTAssertEqual(Set(files.map(\.path)).count, files.count)
        for file in files {
            XCTAssertEqual(file.sha256.count, 64)
            XCTAssertGreaterThan(file.size, 0)
            XCTAssertEqual(file.url.host, "huggingface.co")
            XCTAssertFalse(file.url.path.contains("/main/"))
            XCTAssertFalse(file.path.contains(".."))
        }
    }

    func testMissingModelFailsWithoutDownloading() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let transcriber = WatchTranscriber(directory: directory)
        do {
            _ = try await transcriber.transcribe(audio: directory.appendingPathComponent("missing.wav"), language: "sv")
            XCTFail("Transcription must require an explicitly installed model.")
        } catch WatchTranscriptionError.modelMissing { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    /// Optional hardware/simulator gate. Stage the pinned model and synthetic audio in the app container first.
    func testLocalSwedishAndEnglishSpeech() async throws {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mumla")
        let transcriber = WatchTranscriber(directory: support.appendingPathComponent("WhisperBase-v1"))
        let english = support.appendingPathComponent("smoke-en.wav")
        let swedish = support.appendingPathComponent("smoke-sv.wav")
        guard transcriber.isInstalled, FileManager.default.fileExists(atPath: english.path),
              FileManager.default.fileExists(atPath: swedish.path) else {
            throw XCTSkip("Stage the pinned model and synthetic speech to run local inference.")
        }
        let en = try await transcriber.transcribe(audio: english, language: "en").lowercased()
        XCTAssertLessThanOrEqual(WordErrorRate.score(reference: "Remember to book the meeting room tomorrow morning.", hypothesis: en).errorRate, 0.25, en)
        let sv = try await transcriber.transcribe(audio: swedish, language: "sv").lowercased()
        XCTAssertLessThanOrEqual(WordErrorRate.score(reference: "Vi ses klockan två. Kom ihåg att boka mötesrummet.", hypothesis: sv).errorRate, 0.3, sv)
        let attachment = XCTAttachment(string: "English: \(en)\nSwedish: \(sv)")
        attachment.name = "watch-local-speech"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
