@preconcurrency import AVFoundation
import XCTest
@testable import Mumla

@MainActor
final class KeyboardAudioCaptureTests: XCTestCase {
    func testKeyboardSessionAllowsOtherAppsAudioWithoutActivatingMicrophone() throws {
        let audio = AVAudioSession.sharedInstance()
        let category = audio.category, mode = audio.mode, options = audio.categoryOptions
        defer { try? audio.setCategory(category, mode: mode, options: options) }

        try KeyboardAudioCapture().configureAudioSession()

        XCTAssertEqual(audio.category, .playAndRecord)
        XCTAssertEqual(audio.mode, .measurement)
        XCTAssertTrue(audio.categoryOptions.contains(.mixWithOthers))
    }

    func testAudioTapCanBeCreatedAndCalledOnAudioQueue() async {
        let capture = KeyboardAudioCapture()
        let delivered = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let tap = AudioTapInvocation(capture.makeInputTap())
                continuation.resume(returning: tap.deliver(amplitude: 0.1, frames: 256))
            }
        }
        XCTAssertTrue(delivered)
        XCTAssertEqual(capture.inputLevel, 0.8, accuracy: 0.001)
    }

    func testAudioTapCreatedOnMainActorRunsOnBackgroundQueue() async {
        let capture = KeyboardAudioCapture()
        let tap = AudioTapInvocation(capture.makeInputTap())

        let delivered = await deliver(tap, amplitude: 0.1)

        XCTAssertTrue(delivered.offMainThread)
        XCTAssertTrue(delivered.createdBuffer)
        XCTAssertEqual(capture.inputLevel, 0.8, accuracy: 0.001)
    }

    func testAudioTapClampsLoudInputAndHandlesEmptyBuffers() async {
        let capture = KeyboardAudioCapture()
        let tap = AudioTapInvocation(capture.makeInputTap())

        let loud = await deliver(tap, amplitude: 1)
        XCTAssertTrue(loud.createdBuffer)
        XCTAssertEqual(capture.inputLevel, 1)

        let empty = await deliver(tap, amplitude: 0, frames: 0)
        XCTAssertTrue(empty.createdBuffer)
        XCTAssertEqual(capture.inputLevel, 0)
    }

    func testLateAudioTapDoesNotRetainCapture() async {
        var capture: KeyboardAudioCapture? = KeyboardAudioCapture()
        weak var weakCapture = capture
        let tap = AudioTapInvocation(capture!.makeInputTap())
        capture = nil
        XCTAssertNil(weakCapture)

        let delivered = await deliver(tap, amplitude: 0.1)
        XCTAssertTrue(delivered.offMainThread)
        XCTAssertTrue(delivered.createdBuffer)
        XCTAssertNil(weakCapture)
    }

    private func deliver(_ tap: AudioTapInvocation, amplitude: Float, frames: AVAudioFrameCount = 256) async
        -> (offMainThread: Bool, createdBuffer: Bool) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let offMainThread = !Thread.isMainThread
                let createdBuffer = tap.deliver(amplitude: amplitude, frames: frames)
                continuation.resume(returning: (offMainThread, createdBuffer))
            }
        }
    }
}

// The callback and its buffers are owned by the test's simulated audio queue.
private final class AudioTapInvocation: @unchecked Sendable {
    private let block: AVAudioNodeTapBlock

    init(_ block: @escaping AVAudioNodeTapBlock) { self.block = block }

    func deliver(amplitude: Float, frames: AVAudioFrameCount) -> Bool {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(frames, 1)),
              let samples = buffer.floatChannelData?.pointee else { return false }
        buffer.frameLength = frames
        samples.initialize(repeating: amplitude, count: Int(frames))
        block(buffer, AVAudioTime(sampleTime: 0, atRate: format.sampleRate))
        return true
    }
}
