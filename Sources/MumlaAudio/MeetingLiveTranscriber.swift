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
    private var diarizers: [MeetingTrack: LSEENDDiarizer] = [:]
    private var diarized: Set<String> = []
    private var diarizerSeconds: [MeetingTrack: Double] = [:]
    public private(set) var speakerLabelsFailed = false

    public init(modelDirectory: URL, speakerModelURL: URL? = nil) {
        transcriber = LocalPianissimoTranscriber(modelDirectory: modelDirectory)
        self.speakerModelURL = speakerModelURL
    }

    public func prepare() async throws { try await transcriber.warmUp() }

    public func process(chunk: MeetingAudioChunk, meeting: MeetingRecord, store: MeetingStore) async throws -> [MeetingSegment] {
        try Task.checkCancellation()
        if activeMeetingID != meeting.id {
            activeMeetingID = meeting.id; diarizers.removeAll(); diarized.removeAll(); diarizerSeconds.removeAll(); speakerLabelsFailed = false
        }
        let trackChunks = meeting.chunks.filter { $0.track == chunk.track }.sorted { $0.start < $1.start }
        guard let index = trackChunks.firstIndex(where: { $0.id == chunk.id }) else { throw MeetingStoreError.invalidData }
        let current = try Self.read(try store.audioURL(chunk, meetingID: meeting.id))
        var prefix: [Float] = []
        var suffix: [Float] = []
        if index > 0 {
            let previous = trackChunks[index - 1]
            if abs(previous.start + previous.duration - chunk.start) < 0.1 {
                prefix = Array(try Self.read(try store.audioURL(previous, meetingID: meeting.id)).suffix(32_000))
            }
        }
        if index + 1 < trackChunks.count {
            let next = trackChunks[index + 1]
            if abs(chunk.start + chunk.duration - next.start) < 0.1 {
                suffix = Array(try Self.read(try store.audioURL(next, meetingID: meeting.id)).prefix(16_000))
            }
        }
        var diarizerBase = 0.0
        if let speakerModelURL, !speakerLabelsFailed {
            do {
                if diarizers[chunk.track] == nil {
                    try MeetingSpeakerModel.verifySource(for: speakerModelURL)
                    let model = try LSEENDModel(modelURL: speakerModelURL)
                    diarizers[chunk.track] = try LSEENDDiarizer(model: model,
                        timelineConfig: DiarizerTimelineConfig(maxStoredFrames: 300))
                }
                if let diarizer = diarizers[chunk.track] {
                    for item in trackChunks.prefix(index + 1) {
                        if item.id == chunk.id { diarizerBase = diarizerSeconds[chunk.track, default: 0] }
                        guard !diarized.contains(item.id) else { continue }
                        let samples = item.id == chunk.id ? current : try Self.read(try store.audioURL(item, meetingID: meeting.id))
                        try diarizer.addAudio(samples, sourceSampleRate: 16_000)
                        _ = try diarizer.process()
                        diarizerSeconds[chunk.track, default: 0] += Double(samples.count) / 16_000
                        diarized.insert(item.id)
                    }
                }
            } catch {
                try Task.checkCancellation()
                speakerLabelsFailed = true; diarizers.removeAll()
            }
        }
        // Pure digital silence must not produce invented words or load the ASR model.
        guard current.contains(where: { abs($0) > 0.00001 }) else { return [] }
        let words = try await transcriber.transcribeMeeting(samples: prefix + current + suffix)
        try Task.checkCancellation()
        let prefixSeconds = Double(prefix.count) / 16_000
        let absoluteWords = words.map { MeetingWord(text: $0.text, start: chunk.start + $0.start - prefixSeconds,
                                                    end: chunk.start + $0.end - prefixSeconds) }
        let previousWords = meeting.orderedSegments.filter { $0.track == chunk.track && $0.end >= chunk.start - 3 }
            .flatMap { $0.words ?? [] }
        let committed = MeetingTranscriptBoundary.committedPrefixCount(previous: previousWords, incoming: absoluteWords, boundary: chunk.start)
        let speakers = diarizers[chunk.track]?.timeline.speakers ?? [:]
        var segments: [MeetingSegment] = []
        for word in words.dropFirst(committed) {
            let midpoint = (word.start + word.end) / 2 - prefixSeconds
            guard midpoint >= 0, midpoint < chunk.duration else { continue }
            let modelTime = diarizerBase + midpoint
            let matching = speakers.values.filter { speaker in
                (speaker.finalizedSegments + speaker.tentativeSegments).contains {
                    modelTime >= Double($0.startTime) && modelTime <= Double($0.endTime)
                }
            }
            let speaker = matching.count == 1 ? chunk.track.rawValue + "-" + String(matching[0].index) : chunk.track.rawValue
            let start = chunk.start + max(0, word.start - prefixSeconds)
            let end = chunk.start + min(chunk.duration, word.end - prefixSeconds)
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
