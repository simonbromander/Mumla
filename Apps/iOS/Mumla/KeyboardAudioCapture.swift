@preconcurrency import AVFoundation
import Foundation
import MumlaAudio

struct KeyboardCaptureFailure: Error {
    var url: URL
    var underlyingError: Error
}

final class KeyboardAudioCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var writer: AVAudioFile?
    private var clipURL: URL?
    private var writeError: Error?
    private var level: Double = 0
    private var format: AVAudioFormat?
    private var tapInstalled = false

    @MainActor func startSession() throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.record, mode: .measurement)
        try audio.setActive(true)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw MicrophoneError.unavailable }
        self.format = format
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in self?.capture(buffer) }
        tapInstalled = true
        engine.prepare()
        do { try engine.start() }
        catch { input.removeTap(onBus: 0); tapInstalled = false; throw error }
    }

    @MainActor func startClip() throws {
        guard engine.isRunning, let format else { throw MicrophoneError.unavailable }
        let directory = ModelPathResolver.appSupportDirectory().appendingPathComponent("KeyboardClips", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.protectionKey: FileProtectionType.complete])
        let url = directory.appendingPathComponent("\(UUID().uuidString).caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        try lock.withLock {
            guard writer == nil else { throw MicrophoneError.alreadyRecording }
            clipURL = url; writeError = nil; writer = file
        }
    }

    @MainActor func stopClip() throws -> URL {
        try lock.withLock {
            guard let url = clipURL else { throw MicrophoneError.notRecording }
            writer = nil; clipURL = nil
            if let writeError { self.writeError = nil; throw KeyboardCaptureFailure(url: url, underlyingError: writeError) }
            return url
        }
    }

    @MainActor func cancelClip() {
        let url = lock.withLock { let url = clipURL; writer = nil; clipURL = nil; writeError = nil; return url }
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    @MainActor func endSession() {
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        // Unexpected session loss closes the file for recovery; only explicit cancel deletes it.
        lock.withLock { writer = nil; clipURL = nil; writeError = nil; level = 0 }
        format = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    var inputLevel: Double { lock.withLock { level } }
    @MainActor var isRunning: Bool { engine.isRunning }

    private func capture(_ buffer: AVAudioPCMBuffer) {
        var energy: Float = 0
        if let channel = buffer.floatChannelData?.pointee, buffer.frameLength > 0 {
            for index in 0..<Int(buffer.frameLength) { energy += channel[index] * channel[index] }
            energy = sqrt(energy / Float(buffer.frameLength))
        }
        lock.withLock {
            level = min(1, max(0, Double(energy) * 8))
            // An armed session measures input, but persists audio only for an explicit clip.
            guard let writer, writeError == nil else { return }
            do { try writer.write(from: buffer) } catch { writeError = error }
        }
    }

    private enum MicrophoneError: Error { case unavailable, alreadyRecording, notRecording }
}
