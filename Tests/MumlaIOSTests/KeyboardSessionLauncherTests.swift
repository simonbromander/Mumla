import XCTest
@testable import Mumla

@MainActor
final class KeyboardSessionLauncherTests: XCTestCase {
    func testOnlyExplicitFreshForegroundRequestCanBeConsumedOnce() {
        let launcher = KeyboardSessionLauncher()
        let now = Date(timeIntervalSince1970: 1_791_331_200)
        XCTAssertFalse(launcher.consumeStart(isForeground: true, at: now))
        launcher.requestStart(at: now)
        XCTAssertFalse(launcher.consumeStart(isForeground: false, at: now))
        XCTAssertNotNil(launcher.requestID)
        XCTAssertTrue(launcher.consumeStart(isForeground: true, at: now.addingTimeInterval(1)))
        XCTAssertNil(launcher.requestID)
        XCTAssertFalse(launcher.consumeStart(isForeground: true, at: now.addingTimeInterval(2)))
    }

    func testOldOrFutureRequestNeverStartsMicrophoneLater() {
        let launcher = KeyboardSessionLauncher()
        let now = Date(timeIntervalSince1970: 1_791_331_200)
        for age in [-1.0, 30, 60] {
            launcher.requestStart(at: now)
            XCTAssertFalse(launcher.consumeStart(isForeground: true, at: now.addingTimeInterval(age)))
            XCTAssertNil(launcher.requestID)
        }
    }
}
