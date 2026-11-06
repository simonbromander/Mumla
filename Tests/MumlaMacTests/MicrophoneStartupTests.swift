import AVFoundation
import MumlaAudio
import XCTest

final class MicrophoneStartupTests: XCTestCase {
    func testActualMicrophoneStartupOnSyntheticTimingRun() async throws {
        guard ProcessInfo.processInfo.environment["MUMLA_TEST_MIC_STARTUP"] == "1" else {
            throw XCTSkip("Opt-in local microphone timing check")
        }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw XCTSkip("Microphone permission must already be granted")
        }
        let recorder = MicrophoneRecorder()
        defer { recorder.cancel() }
        for index in 0..<3 {
            let start = ContinuousClock.now
            let url = try recorder.start()
            defer { try? FileManager.default.removeItem(at: url) }
            let elapsed = start.duration(to: .now)
            try await Task.sleep(for: .milliseconds(250))
            _ = try recorder.stop()
            let file = try AVAudioFile(forReading: url)
            XCTAssertGreaterThan(file.length, 0)
            print("Microphone start \(index): \(elapsed)")
        }
    }
}
