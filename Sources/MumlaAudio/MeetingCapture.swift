#if os(macOS)
@preconcurrency import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation
import MumlaCore

public enum MeetingCaptureError: Error, LocalizedError {
    case audio(OSStatus), sourceUnavailable, overloaded, diskSpace
    public var errorDescription: String? {
        switch self {
        case .audio: "Could not capture audio. Check microphone and system audio recording permissions."
        case .sourceUnavailable: "No audio process was found for this app. Start your call, then try again."
        case .overloaded: "Audio could not be saved fast enough. The recording has been stopped and saved."
        case .diskSpace: "There is not enough disk space to safely continue recording."
        }
    }
}

public enum MeetingAudioSource: Identifiable, Equatable, Sendable {
    case systemAudio
    case application(id: Int32, name: String, bundleID: String)

    public init(id: Int32, name: String, bundleID: String) { self = .application(id: id, name: name, bundleID: bundleID) }
    public var id: Int32 {
        switch self {
        case .systemAudio: -1
        case .application(let id, _, _): id
        }
    }
    public var name: String {
        switch self {
        case .systemAudio: "System audio"
        case .application(_, let name, _): name
        }
    }
    public var bundleID: String {
        switch self {
        case .systemAudio: ""
        case .application(_, _, let bundleID): bundleID
        }
    }
}

/// Owns both sources. File conversion and commits use bounded serial writer queues.
public protocol MeetingCapturing: AnyObject {
    func start(store: MeetingStore, meetingID: UUID, microphoneUID: String?, source: MeetingAudioSource?,
               offset: TimeInterval, onChunk: @escaping @Sendable () -> Void,
               onFailure: @escaping @Sendable (String) -> Void) throws
    func stop()
    func level(_ track: MeetingTrack) -> Double
}

public final class MeetingCapture: MeetingCapturing, @unchecked Sendable {
    private var microphone: MeetingMicrophoneInput?
    private var system: (any MeetingSystemCapturing)?
    private var writers: [MeetingTrack: MeetingTrackWriter] = [:]

    public init() {}

    public func start(store: MeetingStore, meetingID: UUID, microphoneUID: String?, source: MeetingAudioSource?,
                      offset: TimeInterval, onChunk: @escaping @Sendable () -> Void,
                      onFailure: @escaping @Sendable (String) -> Void) throws {
        guard microphone == nil, system == nil else { throw MicrophoneRecorderError.alreadyRecording }
        let micWriter = MeetingTrackWriter(store: store, meetingID: meetingID, track: .microphone,
            offset: offset, onChunk: onChunk, onFailure: onFailure)
        writers[.microphone] = micWriter
        do {
            let input = try MeetingMicrophoneInput(deviceUID: microphoneUID, writer: micWriter)
            microphone = input
            if let source {
                guard #available(macOS 14.2, *) else { throw MeetingCaptureError.sourceUnavailable }
                let writer = MeetingTrackWriter(store: store, meetingID: meetingID, track: .system,
                    offset: offset, onChunk: onChunk, onFailure: onFailure)
                writers[.system] = writer
                system = try MeetingSystemInput(source: source, writer: writer)
            }
            // Both writers share the same monotonic origin; startup skew is retained.
            let origin = ProcessInfo.processInfo.systemUptime
            for writer in writers.values { writer.origin = origin }
            try system?.start()
            try input.start()
        } catch {
            stop()
            throw error
        }
    }

    public func stop() {
        microphone?.stop(); system?.stop()
        microphone = nil; system = nil
        for writer in writers.values { writer.finish() }
        writers.removeAll()
    }

    public func level(_ track: MeetingTrack) -> Double { writers[track]?.level ?? 0 }

    @available(macOS 14.2, *)
    static func tapDescription(for source: MeetingAudioSource, processObjectIDs: [AudioObjectID]) throws -> CATapDescription {
        let description: CATapDescription
        switch source {
        case .systemAudio:
            // Mumla may not have a HAL process until its first audio stream starts.
            description = CATapDescription(stereoGlobalTapButExcludeProcesses: processObjectIDs)
        case .application:
            guard !processObjectIDs.isEmpty else { throw MeetingCaptureError.sourceUnavailable }
            description = CATapDescription(stereoMixdownOfProcesses: processObjectIDs)
        }
        description.isPrivate = true
        description.muteBehavior = .unmuted
        return description
    }

    #if DEBUG
    static func writeFixture(_ samples: [Float], track: MeetingTrack, store: MeetingStore,
                             meetingID: UUID, offset: Double = 0, sampleRate: Double = 16_000,
                             channels: AVAudioChannelCount = 1) throws {
        let writer = MeetingTrackWriter(store: store, meetingID: meetingID, track: track, offset: offset,
            onChunk: {}, onFailure: { _ in })
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: channels, interleaved: false)!
        try writer.prepare(format: format, capacity: 2048)
        writer.origin = ProcessInfo.processInfo.systemUptime
        for position in stride(from: 0, to: samples.count, by: 1024) {
            let count = min(1024, samples.count - position)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
            buffer.frameLength = AVAudioFrameCount(count)
            samples.withUnsafeBufferPointer { source in
                for channel in 0..<Int(channels) { buffer.floatChannelData![channel].update(from: source.baseAddress! + position, count: count) }
            }
            writer.receive(buffer.audioBufferList, frames: buffer.frameLength)
            // The fixture has no real-time clock; drain each buffer deterministically.
            writer.queue.sync {}
        }
        writer.finish()
    }
    #endif
}

private final class MeetingTrackWriter: @unchecked Sendable {
    let queue = DispatchQueue(label: "app.mumla.meeting-writer", qos: .userInitiated)
    var origin: TimeInterval = 0
    private let lock = NSLock()
    private var buffers: [AVAudioPCMBuffer] = []
    private var format: AVAudioFormat?
    private var converter: AVAudioConverter?
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    private let store: MeetingStore
    private let meetingID: UUID
    private let track: MeetingTrack
    private let offset: TimeInterval
    private let onChunk: @Sendable () -> Void
    private let onFailure: @Sendable (String) -> Void
    private var file: AVAudioFile?
    private var pendingURL: URL?
    private var chunkID = ""
    private var chunkStart = 0.0
    private var chunkFrames = 0
    private var totalFrames = 0
    private var firstSampleOffset: TimeInterval?
    private var failed = false
    private var meter = 0.0

    init(store: MeetingStore, meetingID: UUID, track: MeetingTrack, offset: TimeInterval,
         onChunk: @escaping @Sendable () -> Void, onFailure: @escaping @Sendable (String) -> Void) {
        self.store = store; self.meetingID = meetingID; self.track = track; self.offset = offset
        self.onChunk = onChunk; self.onFailure = onFailure
    }

    var level: Double { lock.withLock { meter } }

    func prepare(format: AVAudioFormat, capacity: AVAudioFrameCount) throws {
        self.format = format
        converter = AVAudioConverter(from: format, to: target)
        guard converter != nil else { throw MeetingCaptureError.sourceUnavailable }
        buffers = (0..<24).compactMap { _ in AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) }
        guard buffers.count == 24 else { throw MeetingCaptureError.sourceUnavailable }
    }

    func receive(_ data: UnsafePointer<AudioBufferList>, frames: AVAudioFrameCount) {
        guard frames > 0 else { return }
        guard let buffer = lock.withLock({ buffers.popLast() }) else { fail(MeetingCaptureError.overloaded); return }
        guard frames <= buffer.frameCapacity else {
            lock.withLock { buffers.append(buffer) }; fail(MeetingCaptureError.overloaded); return
        }
        buffer.frameLength = frames
        let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: data))
        let destination = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        guard source.count == destination.count else {
            lock.withLock { buffers.append(buffer) }; fail(MeetingCaptureError.sourceUnavailable); return
        }
        for index in source.indices {
            guard source[index].mDataByteSize >= destination[index].mDataByteSize,
                  let input = source[index].mData, let output = destination[index].mData else {
                lock.withLock { buffers.append(buffer) }; fail(MeetingCaptureError.sourceUnavailable); return
            }
            memcpy(output, input, Int(destination[index].mDataByteSize))
        }
        let receivedAt = ProcessInfo.processInfo.systemUptime
        queue.async { [self] in
            defer { lock.withLock { buffers.append(buffer) } }
            guard !lock.withLock({ failed }) else { return }
            do { try write(buffer, receivedAt: receivedAt) } catch { fail(error) }
        }
    }

    func finish() {
        queue.sync { do { try closeChunk() } catch { fail(error) } }
    }

    private func write(_ input: AVAudioPCMBuffer, receivedAt: TimeInterval) throws {
        guard let converter else { return }
        if firstSampleOffset == nil { firstSampleOffset = max(0, receivedAt - origin - Double(input.frameLength) / input.format.sampleRate) }
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * 16_000 / input.format.sampleRate)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { throw MeetingCaptureError.overloaded }
        let supply = MeetingConversionSupply()
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supply.supplied { status.pointee = .noDataNow; return nil }
            supply.supplied = true; status.pointee = .haveData; return input
        }
        if let error { throw error }
        guard output.frameLength > 0, let samples = output.floatChannelData?[0] else { return }
        var sum: Float = 0
        for i in 0..<Int(output.frameLength) { sum += samples[i] * samples[i] }
        lock.withLock { meter = min(1, Double(sqrt(sum / Float(output.frameLength))) * 5) }
        var position = 0
        while position < Int(output.frameLength) {
            if file == nil { try openChunk() }
            let count = min(48_000 - chunkFrames, Int(output.frameLength) - position)
            guard let slice = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: AVAudioFrameCount(count)),
                  let destination = slice.floatChannelData?[0] else { throw MeetingCaptureError.overloaded }
            slice.frameLength = AVAudioFrameCount(count)
            destination.update(from: samples + position, count: count)
            try file?.write(from: slice)
            chunkFrames += count; totalFrames += count; position += count
            if chunkFrames == 48_000 { try closeChunk() }
        }
    }

    private func openChunk() throws {
        let values = try store.directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        guard (values.volumeAvailableCapacity ?? 0) > 50_000_000 else { throw MeetingCaptureError.diskSpace }
        chunkID = track.rawValue + "-" + UUID().uuidString
        chunkStart = offset + (firstSampleOffset ?? 0) + Double(totalFrames) / 16_000
        let url = store.folder(meetingID).appendingPathComponent(chunkID + ".partial.wav")
        file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
        pendingURL = url; chunkFrames = 0
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func closeChunk() throws {
        guard let pendingURL else { return }
        file = nil
        self.pendingURL = nil
        guard chunkFrames > 0 else { try? FileManager.default.removeItem(at: pendingURL); return }
        let chunk = MeetingAudioChunk(id: chunkID, track: track, start: chunkStart, duration: Double(chunkFrames) / 16_000)
        let url = try store.audioURL(chunk, meetingID: meetingID)
        try FileManager.default.moveItem(at: pendingURL, to: url)
        try JSONEncoder().encode(chunk).write(to: url.appendingPathExtension("json"), options: .atomic)
        try store.appendChunk(chunk, meetingID: meetingID)
        onChunk()
    }

    func fail(_ error: Error) {
        let first = lock.withLock { let first = !failed; failed = true; return first }
        if first { queue.async { [onFailure] in onFailure(error.localizedDescription) } }
    }
}

private final class MeetingMicrophoneInput {
    private let unit: AudioUnit
    private let writer: MeetingTrackWriter
    private let buffer: AVAudioPCMBuffer
    private var running = false

    init(deviceUID: String?, writer: MeetingTrackWriter) throws {
        self.writer = writer
        if let deviceUID, AudioInputDevices.deviceID(forUID: deviceUID) == nil { throw MeetingCaptureError.sourceUnavailable }
        var device = deviceUID.flatMap(AudioInputDevices.deviceID(forUID:)) ?? 0
        if device == 0 {
            var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            try meetingAudioCheck(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device))
        }
        var description = AudioComponentDescription(componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput, componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0, componentFlagsMask: 0)
        var instance: AudioUnit?
        guard let component = AudioComponentFindNext(nil, &description),
              AudioComponentInstanceNew(component, &instance) == noErr, let unit = instance else { throw MeetingCaptureError.sourceUnavailable }
        self.unit = unit
        do {
            var yes: UInt32 = 1; var no: UInt32 = 0
            try meetingAudioCheck(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &yes, 4))
            try meetingAudioCheck(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &no, 4))
            try meetingAudioCheck(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device, 4))
            var native = AudioStreamBasicDescription(); var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            try meetingAudioCheck(AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &native, &size))
            guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: native.mSampleRate,
                channels: native.mChannelsPerFrame, interleaved: false),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_384) else { throw MeetingCaptureError.sourceUnavailable }
            self.buffer = buffer
            try meetingAudioCheck(AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1,
                format.streamDescription, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)))
            var maximumFrames: UInt32 = buffer.frameCapacity
            try meetingAudioCheck(AudioUnitSetProperty(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                &maximumFrames, UInt32(MemoryLayout<UInt32>.size)))
            try writer.prepare(format: format, capacity: 16_384)
        } catch { AudioComponentInstanceDispose(unit); throw error }
    }

    func start() throws {
        var callback = AURenderCallbackStruct(inputProc: { context, flags, time, _, frames, _ in
            let input = Unmanaged<MeetingMicrophoneInput>.fromOpaque(context).takeUnretainedValue()
            guard frames <= input.buffer.frameCapacity else {
                input.writer.fail(MeetingCaptureError.overloaded)
                return kAudioUnitErr_TooManyFramesToProcess
            }
            input.buffer.frameLength = frames
            let status = AudioUnitRender(input.unit, flags, time, 1, frames, input.buffer.mutableAudioBufferList)
            if status == noErr { input.writer.receive(input.buffer.audioBufferList, frames: frames) }
            else { input.writer.fail(MeetingCaptureError.audio(status)) }
            return status
        }, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        try meetingAudioCheck(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0,
            &callback, UInt32(MemoryLayout<AURenderCallbackStruct>.size)))
        try meetingAudioCheck(AudioUnitInitialize(unit))
        try meetingAudioCheck(AudioOutputUnitStart(unit)); running = true
    }
    func stop() { if running { AudioOutputUnitStop(unit); running = false }; AudioUnitUninitialize(unit) }
    deinit { stop(); AudioComponentInstanceDispose(unit) }
}

private final class MeetingConversionSupply: @unchecked Sendable { var supplied = false }

private protocol MeetingSystemCapturing: AnyObject {
    func start() throws
    func stop()
}

@available(macOS 14.2, *)
private final class MeetingSystemInput: MeetingSystemCapturing {
    private var tap: AudioObjectID = 0
    private var device: AudioObjectID = 0
    private var io: AudioDeviceIOProcID?
    private let writer: MeetingTrackWriter
    private var running = false

    init(source: MeetingAudioSource, writer: MeetingTrackWriter) throws {
        self.writer = writer
        do {
            let processes = try Self.processes(for: source)
            let description = try MeetingCapture.tapDescription(for: source, processObjectIDs: processes)
            try meetingAudioCheck(AudioHardwareCreateProcessTap(description, &tap))
            var address = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var stream = AudioStreamBasicDescription(); var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            try meetingAudioCheck(AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &stream))
            guard let format = AVAudioFormat(streamDescription: &stream) else { throw MeetingCaptureError.sourceUnavailable }
            try writer.prepare(format: format, capacity: 16_384)
            let aggregate: [String: Any] = [kAudioAggregateDeviceNameKey: "Mumla Meeting",
                kAudioAggregateDeviceUIDKey: UUID().uuidString, kAudioAggregateDeviceIsPrivateKey: true,
                // A tap-only aggregate avoids accidentally capturing a hardware input twice.
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString, kAudioSubTapDriftCompensationKey: true]]]
            try meetingAudioCheck(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &device))
            let bytesPerFrame = stream.mBytesPerFrame
            try meetingAudioCheck(AudioDeviceCreateIOProcIDWithBlock(&io, device, nil) { _, input, _, _, _ in
                let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
                guard let first = list.first, bytesPerFrame > 0 else { return }
                writer.receive(input, frames: first.mDataByteSize / bytesPerFrame)
            })
        } catch { cleanup(); throw error }
    }
    func start() throws { try meetingAudioCheck(AudioDeviceStart(device, io)); running = true }
    func stop() { if running { AudioDeviceStop(device, io); running = false } }
    private func cleanup() {
        stop()
        if let io, device != 0 { AudioDeviceDestroyIOProcID(device, io); self.io = nil }
        if device != 0 { AudioHardwareDestroyAggregateDevice(device); device = 0 }
        if tap != 0 { AudioHardwareDestroyProcessTap(tap); tap = 0 }
    }
    deinit { cleanup() }

    private static func processes(for source: MeetingAudioSource) throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        try meetingAudioCheck(AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size))
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        try meetingAudioCheck(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids))
        return ids.filter { object in
            var property = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyPID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var pid: pid_t = 0; var count: UInt32 = 4
            guard AudioObjectGetPropertyData(object, &property, 0, nil, &count, &pid) == noErr else { return false }
            if source == .systemAudio { return pid == ProcessInfo.processInfo.processIdentifier }
            if pid == source.id { return true }
            property.mSelector = kAudioProcessPropertyBundleID
            var bundle: Unmanaged<CFString>?; count = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(object, &property, 0, nil, &count, &bundle) == noErr,
                  let value = bundle?.takeRetainedValue() as String? else { return false }
            return !source.bundleID.isEmpty && (value == source.bundleID || value.hasPrefix(source.bundleID + "."))
        }
    }
}

private func meetingAudioCheck(_ status: OSStatus) throws {
    guard status == noErr else { throw MeetingCaptureError.audio(status) }
}
#endif
