#if os(macOS)
@preconcurrency import AVFoundation
import FluidAudio
import Foundation
import MumlaCore

/// A bounded, disk-backed ASR window with left/right context. Never sends content to a service.
public actor MeetingLiveTranscriber {
    private let transcriber: LocalPianissimoTranscriber
    private let speakerModelURL: URL?
    private var activeMeetingID: UUID?
    private let speakerFactory: @Sendable (URL) throws -> any MeetingSpeakerStreaming
    private let injectedRecognition: (@Sendable ([Float]) async throws -> [MeetingWord])?
    private var diarizers: [MeetingTrack: any MeetingSpeakerStreaming] = [:]
    private var diarizerOffsets: [String: Int] = [:]
    private var diarizerSamples: [MeetingTrack: Int] = [:]
    private var paddedSpeakerTails: Set<String> = []
    public private(set) var speakerLabelsFailed = false

    public init(modelDirectory: URL, speakerModelURL: URL? = nil) {
        transcriber = LocalPianissimoTranscriber(modelDirectory: modelDirectory)
        self.speakerModelURL = speakerModelURL
        speakerFactory = { try LSEENDMeetingSpeakerStream(modelURL: $0) }
        injectedRecognition = nil
    }

    init(modelDirectory: URL, speakerModelURL: URL,
         speakerFactory: @escaping @Sendable (URL) throws -> any MeetingSpeakerStreaming,
         recognize: @escaping @Sendable ([Float]) async throws -> [MeetingWord]) {
        transcriber = LocalPianissimoTranscriber(modelDirectory: modelDirectory)
        self.speakerModelURL = speakerModelURL
        self.speakerFactory = speakerFactory
        injectedRecognition = recognize
    }

    public func prepare() async throws { try await transcriber.warmUp() }

    public func process(chunk: MeetingAudioChunk, meeting: MeetingRecord, store: MeetingStore) async throws -> [MeetingSegment] {
        try Task.checkCancellation()
        if activeMeetingID != meeting.id {
            activeMeetingID = meeting.id; diarizers.removeAll(); diarizerOffsets.removeAll()
            diarizerSamples.removeAll(); paddedSpeakerTails.removeAll(); speakerLabelsFailed = false
        }
        let trackChunks = meeting.chunks.filter { $0.track == chunk.track }.sorted { $0.start < $1.start }
        guard let index = trackChunks.firstIndex(where: { $0.id == chunk.id }) else { throw MeetingStoreError.invalidData }
        let current = try Self.read(try store.audioURL(chunk, meetingID: meeting.id))
        var prefix: [Float] = []
        var suffix: [Float] = []
        var following: [Float]?
        if index > 0 {
            let previous = trackChunks[index - 1]
            if abs(previous.start + previous.duration - chunk.start) < 0.1 {
                prefix = Array(try Self.read(try store.audioURL(previous, meetingID: meeting.id)).suffix(32_000))
            }
        }
        if index + 1 < trackChunks.count {
            let next = trackChunks[index + 1]
            if abs(chunk.start + chunk.duration - next.start) < 0.1 {
                following = try Self.read(try store.audioURL(next, meetingID: meeting.id))
                suffix = Array(following!.prefix(16_000))
            }
        }
        var diarizerBase = 0.0
        if let speakerModelURL, !speakerLabelsFailed {
            do {
                if diarizers[chunk.track] == nil {
                    diarizers[chunk.track] = try speakerFactory(speakerModelURL)
                }
                if let diarizer = diarizers[chunk.track] {
                    let through = index + (following == nil ? 0 : 1)
                    for itemIndex in 0...through {
                        let item = trackChunks[itemIndex]
                        guard diarizerOffsets[item.id] == nil else { continue }
                        try Task.checkCancellation()
                        if itemIndex > 0 {
                            let previous = trackChunks[itemIndex - 1]
                            if abs(previous.start + previous.duration - item.start) >= 0.1 {
                                try drainSpeakerTail(previous, stream: diarizer)
                            }
                        }
                        let samples: [Float]
                        if item.id == chunk.id { samples = current }
                        else if itemIndex == index + 1, let following { samples = following }
                        else { samples = try Self.read(try store.audioURL(item, meetingID: meeting.id)) }
                        let offset = diarizerSamples[chunk.track, default: 0]
                        try diarizer.addAudio(samples)
                        try diarizer.process()
                        diarizerOffsets[item.id] = offset
                        diarizerSamples[chunk.track, default: 0] += samples.count
                    }
                    let tail = trackChunks[through]
                    let atEnd = through == trackChunks.count - 1
                    let gapAfter = !atEnd && abs(tail.start + tail.duration - trackChunks[through + 1].start) >= 0.1
                    if atEnd && (meeting.capture == .saved || meeting.capture == .interrupted) {
                        try diarizer.finish()
                    } else if (atEnd && meeting.capture == .paused) || gapAfter {
                        try drainSpeakerTail(tail, stream: diarizer)
                    }
                    diarizerBase = Double(diarizerOffsets[chunk.id, default: 0]) / 16_000
                }
            } catch {
                try Task.checkCancellation()
                speakerLabelsFailed = true; diarizers.removeAll()
            }
        }
        // Pure digital silence must not produce invented words or load the ASR model.
        guard current.contains(where: { abs($0) > 0.00001 }) else { return [] }
        let words: [MeetingWord]
        if let injectedRecognition { words = try await injectedRecognition(prefix + current + suffix) }
        else { words = try await transcriber.transcribeMeeting(samples: prefix + current + suffix) }
        try Task.checkCancellation()
        let prefixSeconds = Double(prefix.count) / 16_000
        let absoluteWords = words.map { MeetingWord(text: $0.text, start: chunk.start + $0.start - prefixSeconds,
                                                    end: chunk.start + $0.end - prefixSeconds) }
        let previousWords = meeting.orderedSegments.filter { $0.track == chunk.track && $0.end >= chunk.start - 3 }
            .flatMap { $0.words ?? [] }
        let committed = MeetingTranscriptBoundary.committedPrefixCount(previous: previousWords, incoming: absoluteWords, boundary: chunk.start)
        let regions = diarizers[chunk.track]?.regions(in: diarizerBase..<(diarizerBase + chunk.duration)) ?? []
        var segments: [MeetingSegment] = []
        for word in words.dropFirst(committed) {
            let midpoint = (word.start + word.end) / 2 - prefixSeconds
            guard midpoint >= 0, midpoint < chunk.duration else { continue }
            let start = chunk.start + max(0, word.start - prefixSeconds)
            let end = chunk.start + min(chunk.duration, word.end - prefixSeconds)
            let modelStart = diarizerBase + start - chunk.start
            let modelEnd = diarizerBase + max(start + 1.0 / 16_000, end) - chunk.start
            let assigned = MeetingSpeakerAlignment.index(in: modelStart..<modelEnd, regions: regions)
            let speaker = assigned.map { chunk.track.rawValue + "-" + String($0) } ?? chunk.track.rawValue
            if let last = segments.last, last.speaker == speaker, end - last.start < 12 {
                segments[segments.count - 1].text += " " + word.text
                segments[segments.count - 1].originalText = segments[segments.count - 1].text
                segments[segments.count - 1].end = max(last.end, end)
                segments[segments.count - 1].words?.append(MeetingWord(text: word.text, start: start, end: max(start, end)))
            } else {
                segments.append(MeetingSegment(id: chunk.id + "-" + String(segments.count), chunkID: chunk.id,
                    track: chunk.track, start: start, end: max(start, end), speaker: speaker, text: word.text))
                segments[segments.count - 1].words = [MeetingWord(text: word.text, start: start, end: max(start, end))]
            }
        }
        return segments
    }

    private func drainSpeakerTail(_ chunk: MeetingAudioChunk, stream: any MeetingSpeakerStreaming) throws {
        guard !paddedSpeakerTails.contains(chunk.id) else { return }
        guard stream.paddingSamples > 0, stream.paddingSamples <= 80_000 else { throw MeetingStoreError.invalidData }
        try stream.addAudio([Float](repeating: 0, count: stream.paddingSamples))
        try stream.process()
        diarizerSamples[chunk.track, default: 0] += stream.paddingSamples
        paddedSpeakerTails.insert(chunk.id)
    }

    static func read(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard file.processingFormat.sampleRate == 16_000, file.processingFormat.channelCount == 1,
              file.length > 0, file.length <= 480_000,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw MeetingStoreError.invalidData
        }
        try file.read(into: buffer)
        guard let samples = buffer.floatChannelData?[0] else { throw MeetingStoreError.invalidData }
        return Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
    }
}
#endif
