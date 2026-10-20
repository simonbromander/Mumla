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

    func testUnsupportedDominantLanguageDoesNotBecomeEnglishOrSwedish() {
        for text in [
            "Ceci est une phrase française avec des mots clairement français et une conversation très intéressante.",
            "Dies ist ein deutscher Satz mit eindeutig deutschen Wörtern und einem ausführlichen Gespräch."
        ] {
            XCTAssertNil(AppleTextLanguageRecognizer.detect(text))
        }
    }

    func testEmptyTextHasNoLanguage() {
        XCTAssertNil(AppleTextLanguageRecognizer.detect(" \n"))
    }
}
#endif
