@preconcurrency import AVFoundation
#if os(macOS)
import AudioToolbox
import CoreAudio
#endif
import Foundation

public final class MicrophoneRecorder: NSObject, @unchecked Sendable {
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    #if os(macOS)
    private var deviceCapture: DeviceInputCapture?
    #endif

    private static var fileSettings: [String: Any] { [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false
    ] }

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

    /// Starts recording. On macOS, a connected `inputDeviceUID` is used regardless of the
    /// system default input; otherwise the system default is used.
    public func start(inputDeviceUID: String? = nil) throws -> URL {
        if let recorder, recorder.isRecording {
            throw MicrophoneRecorderError.alreadyRecording
        }
        #if os(macOS)
        if deviceCapture != nil {
            throw MicrophoneRecorderError.alreadyRecording
        }
        #endif

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MumlaRecordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("\(UUID().uuidString).wav")
        #if os(macOS)
        if let inputDeviceUID, let deviceID = AudioInputDevices.deviceID(forUID: inputDeviceUID) {
            do {
                try startDeviceCapture(deviceID: deviceID, url: url)
                self.outputURL = url
                return url
            } catch {
                // The pinned device couldn't start (busy, just disconnected); use the system default.
            }
        }
        #endif

        let recorder = try AVAudioRecorder(url: url, settings: Self.fileSettings)
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
        guard let outputURL else {
            throw MicrophoneRecorderError.notRecording
        }
        #if os(macOS)
        stopDeviceCapture()
        #endif
        recorder?.stop()
        self.recorder = nil
        self.outputURL = nil
        return outputURL
    }

    public func inputLevel() -> Double {
        #if os(macOS)
        if let deviceCapture { return deviceCapture.level }
        #endif
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        return min(1, max(0, pow(10, Double(recorder.averagePower(forChannel: 0)) / 30)))
    }

    public func cancel() {
        let url = outputURL
        #if os(macOS)
        stopDeviceCapture()
        #endif
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        outputURL = nil

        if let url, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

#if os(macOS)
private extension MicrophoneRecorder {
    func startDeviceCapture(deviceID: AudioDeviceID, url: URL) throws {
        let capture = try DeviceInputCapture(deviceID: deviceID, url: url, settings: Self.fileSettings)
        try capture.start()
        self.deviceCapture = capture
    }

    func stopDeviceCapture() {
        deviceCapture?.stop()
        deviceCapture = nil
    }
}

/// Records one input device through an input-only AUHAL unit. Unlike AVAudioEngine, which builds
/// an aggregate of the system default input and output before it can be rebound, this never opens
/// any other device, so Bluetooth headphones playing music stay in their high-quality mode.
private final class DeviceInputCapture: @unchecked Sendable {
    private let unit: AudioUnit
    private let writer: DeviceFileWriter
    private let renderBuffer: AVAudioPCMBuffer
    private let writeQueue = DispatchQueue(label: "se.mumla.device-input-writer")
    private var running = false

    init(deviceID: AudioDeviceID, url: URL, settings: [String: Any]) throws {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        var instance: AudioUnit?
        guard let component = AudioComponentFindNext(nil, &description),
              AudioComponentInstanceNew(component, &instance) == noErr,
              let unit = instance
        else { throw MicrophoneRecorderError.failedToStart }

        do {
            var enable: UInt32 = 1
            var disable: UInt32 = 0
            var device = deviceID
            try Self.check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enable, UInt32(MemoryLayout<UInt32>.size)))
            try Self.check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &disable, UInt32(MemoryLayout<UInt32>.size)))
            try Self.check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device, UInt32(MemoryLayout<AudioDeviceID>.size)))

            var deviceFormat = AudioStreamBasicDescription()
            var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            try Self.check(AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &deviceFormat, &size))
            guard deviceFormat.mSampleRate > 0, deviceFormat.mChannelsPerFrame > 0,
                  let clientFormat = AVAudioFormat(
                      commonFormat: .pcmFormatFloat32,
                      sampleRate: deviceFormat.mSampleRate,
                      channels: deviceFormat.mChannelsPerFrame,
                      interleaved: false
                  )
            else { throw MicrophoneRecorderError.failedToStart }
            try Self.check(AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, clientFormat.streamDescription, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)))

            var maxFrames: UInt32 = 0
            size = UInt32(MemoryLayout<UInt32>.size)
            try Self.check(AudioUnitGetProperty(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, &size))
            guard let renderBuffer = AVAudioPCMBuffer(pcmFormat: clientFormat, frameCapacity: max(maxFrames, 4096)),
                  let writer = try DeviceFileWriter(url: url, inputFormat: clientFormat, settings: settings)
            else { throw MicrophoneRecorderError.failedToStart }
            self.unit = unit
            self.writer = writer
            self.renderBuffer = renderBuffer
        } catch {
            AudioComponentInstanceDispose(unit)
            throw error
        }
    }

    deinit {
        AudioComponentInstanceDispose(unit)
    }

    var level: Double { writer.level }

    func start() throws {
        var callback = AURenderCallbackStruct(
            inputProc: { refCon, flags, timeStamp, _, frameCount, _ in
                Unmanaged<DeviceInputCapture>.fromOpaque(refCon).takeUnretainedValue()
                    .render(flags: flags, timeStamp: timeStamp, frameCount: frameCount)
            },
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        do {
            try Self.check(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callback, UInt32(MemoryLayout<AURenderCallbackStruct>.size)))
            try Self.check(AudioUnitInitialize(unit))
            try Self.check(AudioOutputUnitStart(unit))
            running = true
        } catch {
            AudioUnitUninitialize(unit)
            writer.finish()
            throw error
        }
    }

    /// Stops the device and closes the file once every captured buffer has been written.
    func stop() {
        guard running else { return }
        running = false
        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        writeQueue.sync { writer.finish() }
    }

    private func render(
        flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timeStamp: UnsafePointer<AudioTimeStamp>,
        frameCount: UInt32
    ) -> OSStatus {
        guard frameCount <= renderBuffer.frameCapacity else { return kAudioUnitErr_TooManyFramesToProcess }
        renderBuffer.frameLength = frameCount
        let status = AudioUnitRender(unit, flags, timeStamp, 1, frameCount, renderBuffer.mutableAudioBufferList)
        guard status == noErr,
              let copy = AVAudioPCMBuffer(pcmFormat: renderBuffer.format, frameCapacity: frameCount),
              let source = renderBuffer.floatChannelData,
              let destination = copy.floatChannelData
        else { return status }
        copy.frameLength = frameCount
        for channel in 0..<Int(renderBuffer.format.channelCount) {
            destination[channel].update(from: source[channel], count: Int(frameCount))
        }
        // Conversion and file writes stay off the real-time I/O thread.
        writeQueue.async { [writer] in writer.write(copy) }
        return noErr
    }

    private static func check(_ status: OSStatus) throws {
        guard status == noErr else { throw MicrophoneRecorderError.failedToStart }
    }
}

/// Converts captured device audio to 16 kHz mono and writes it to the recording file.
private final class DeviceFileWriter: @unchecked Sendable {
    private let lock = NSLock()
    private let converter: AVAudioConverter
    private let targetFormat: AVAudioFormat
    private var file: AVAudioFile?
    private var currentLevel: Double = 0

    init?(url: URL, inputFormat: AVAudioFormat, settings: [String: Any]) throws {
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        else { return nil }
        converter.downmix = true
        self.converter = converter
        self.targetFormat = targetFormat
        self.file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    }

    var level: Double {
        lock.lock()
        defer { lock.unlock() }
        return currentLevel
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let file else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
        var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, output.frameLength > 0, let samples = output.floatChannelData?[0] else { return }
        try? file.write(from: output)

        var sum: Float = 0
        for index in 0..<Int(output.frameLength) { sum += samples[index] * samples[index] }
        let rms = sqrt(sum / Float(output.frameLength))
        let decibels = 20 * log10(max(rms, 1e-7))
        // Same mapping as AVAudioRecorder.averagePower in `inputLevel()`.
        currentLevel = min(1, max(0, pow(10, Double(decibels) / 30)))
    }

    /// Closes the file; later writes are ignored.
    func finish() {
        lock.lock()
        defer { lock.unlock() }
        file = nil
        currentLevel = 0
    }
}
#endif

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
