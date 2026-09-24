import XCTest
@testable import MumlaCore

final class PianissimoModelArtifactTests: XCTestCase {
    func testCommunityPianissimoArtifactPinsAllRequiredFiles() {
        let artifact = MumlaModelArtifacts.communityPianissimoCoreML
        let paths = Set(artifact.files.map(\.path))

        XCTAssertEqual(artifact.id, "markstrom/pianissimo-sv-coreml")
        XCTAssertEqual(artifact.revision, "106fa163a138a0db6737e0c50494269e07f508d0")
        XCTAssertEqual(artifact.files.count, 14)
        XCTAssertTrue(paths.contains("Preprocessor.mlpackage/Manifest.json"))
        XCTAssertTrue(paths.contains("Encoder.mlpackage/Data/com.apple.CoreML/weights/weight.bin"))
        XCTAssertTrue(paths.contains("Decoder.mlpackage/Data/com.apple.CoreML/model.mlmodel"))
        XCTAssertTrue(paths.contains("JointDecisionv3.mlpackage/Manifest.json"))
        XCTAssertTrue(paths.contains("parakeet_vocab.json"))
        XCTAssertTrue(artifact.files.allSatisfy { $0.byteCount != nil && $0.sha256?.isEmpty == false })
    }
}
