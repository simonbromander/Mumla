import XCTest
@testable import MumlaCore

final class ModelArtifactTests: XCTestCase {
    func testVerifiesSizeAndChecksum() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("model.bin")
        try Data("mumla".utf8).write(to: fileURL)

        let checksum = try ModelArtifactVerifier.sha256Hex(of: fileURL)
        let artifact = ModelArtifact(
            id: "fixture",
            sourceURL: URL(string: "https://example.com/model")!,
            files: [
                ModelArtifactFile(path: "model.bin", byteCount: 5, sha256: checksum)
            ]
        )

        XCTAssertEqual(
            ModelArtifactVerifier.verify(artifact: artifact, baseDirectory: directory),
            []
        )
    }

    func testReportsMissingFile() {
        let artifact = ModelArtifact(
            id: "fixture",
            sourceURL: URL(string: "https://example.com/model")!,
            files: [
                ModelArtifactFile(path: "missing.bin", byteCount: 1)
            ]
        )

        XCTAssertEqual(
            ModelArtifactVerifier.verify(
                artifact: artifact,
                baseDirectory: FileManager.default.temporaryDirectory
            ),
            [.missingFile("missing.bin")]
        )
    }
}

