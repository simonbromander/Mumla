import XCTest
@testable import MumlaCore

#if canImport(NaturalLanguage)
final class AppleTextLanguageRecognizerTests: XCTestCase {
    func testDetectsSwedishText() {
        let result = AppleTextLanguageRecognizer.detect("Det här är en svensk mening med tydliga ord.")

        XCTAssertEqual(result?.language, .swedish)
    }

    func testDetectsEnglishText() {
        let result = AppleTextLanguageRecognizer.detect("This is an English sentence with clear words.")

        XCTAssertEqual(result?.language, .english)
    }
}
#endif
