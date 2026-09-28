@preconcurrency import AVFoundation
import Foundation

public final class MicrophoneRecorder: NSObject, @unchecked Sendable {
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?

    public override init() {
        super.init()
    }

    public func microphonePermissionGranted() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    public func start() throws -> URL {
        if let recorder, recorder.isRecording {
            throw MicrophoneRecorderError.alreadyRecording
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MumlaRecordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw MicrophoneRecorderError.failedToStart
        }

        self.recorder = recorder
        self.outputURL = url
        return url
    }

    public func stop() throws -> URL {
        guard let recorder, let outputURL else {
            throw MicrophoneRecorderError.notRecording
        }
        recorder.stop()
        self.recorder = nil
        self.outputURL = nil
        return outputURL
    }

    public func inputLevel() -> Double {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        return min(1, max(0, pow(10, Double(recorder.averagePower(forChannel: 0)) / 30)))
    }

    public func cancel() {
        let url = outputURL
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        outputURL = nil

        if let url, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

public enum MicrophoneRecorderError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case failedToStart

    public var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress."
        case .notRecording:
            return "No recording is in progress."
        case .failedToStart:
            return "Could not start microphone recording."
        }
    }
}
