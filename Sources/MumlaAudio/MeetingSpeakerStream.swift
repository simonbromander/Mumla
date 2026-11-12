#if os(macOS)
import FluidAudio
import Foundation
import MumlaCore

struct MeetingSpeakerRegion: Sendable {
    let index: Int
    let start: Double
    let end: Double
}

enum MeetingSpeakerAlignment {
    static func index(in word: Range<Double>, regions: [MeetingSpeakerRegion]) -> Int? {
        var coverage: [Int: [Range<Double>]] = [:]
        for region in regions {
            let start = max(word.lowerBound, region.start)
            let end = min(word.upperBound, region.end)
            if start < end { coverage[region.index, default: []].append(start..<end) }
        }
        // Do not turn overlapping people or a speaker change into one identity.
        guard coverage.count == 1, let (speaker, intervals) = coverage.first else { return nil }
        var covered = 0.0
        var end = word.lowerBound
        for interval in intervals.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            covered += max(0, interval.upperBound - max(end, interval.lowerBound))
            end = max(end, interval.upperBound)
        }
        return covered >= (word.upperBound - word.lowerBound) / 2 ? speaker : nil
    }
}

protocol MeetingSpeakerStreaming: AnyObject, Sendable {
    var paddingSamples: Int { get }
    func addAudio(_ samples: [Float]) throws
    func process() throws
    func finish() throws
    func regions(in interval: Range<Double>) -> [MeetingSpeakerRegion]
}

// Owned and invoked serially by MeetingLiveTranscriber.
final class LSEENDMeetingSpeakerStream: MeetingSpeakerStreaming, @unchecked Sendable {
    private let diarizer: LSEENDDiarizer
    let paddingSamples: Int

    init(modelURL: URL) throws {
        try MeetingSpeakerModel.verifySource(for: modelURL)
        let model = try LSEENDModel(modelURL: modelURL)
        let metadata = model.metadata
        let frameSeconds = Double(metadata.frameDurationSeconds)
        let context = (metadata.contextSize + metadata.convDelay * metadata.subsampling) * metadata.hopLength + metadata.nFFT / 2
        paddingSamples = Int(ceil(Double(context) * 16_000 / Double(metadata.sampleRate) + frameSeconds * 16_000))
        guard paddingSamples > 0, paddingSamples <= 80_000 else { throw MeetingStoreError.invalidData }
        // Two minutes covers the largest accepted ASR chunk plus lookahead;
        // do not retain an ever-growing second copy of speaker segments.
        diarizer = try LSEENDDiarizer(model: model,
            timelineConfig: DiarizerTimelineConfig(maxStoredFrames: 1_200, storeSegments: false))
    }

    func addAudio(_ samples: [Float]) throws { try diarizer.addAudio(samples, sourceSampleRate: 16_000) }
    func process() throws { _ = try diarizer.process() }
    func finish() throws { _ = try diarizer.finalizeSession() }

    func regions(in interval: Range<Double>) -> [MeetingSpeakerRegion] {
        Self.regions(in: interval, timeline: diarizer.timeline)
    }

    static func regions(in interval: Range<Double>, timeline: DiarizerTimeline) -> [MeetingSpeakerRegion] {
        let frameSeconds = Double(timeline.config.frameDurationSeconds)
        let first = max(0, Int(floor(interval.lowerBound / frameSeconds)))
        let last = min(timeline.numFinalizedFrames, Int(ceil(interval.upperBound / frameSeconds)))
        guard first < last else { return [] }
        var result: [MeetingSpeakerRegion] = []
        for frame in first..<last {
            for speaker in 0..<timeline.speakerCapacity {
                if timeline.probability(speaker: speaker, frame: frame) > 0.5 {
                    result.append(.init(index: speaker, start: Double(frame) * frameSeconds, end: Double(frame + 1) * frameSeconds))
                }
            }
        }
        return result
    }
}
#endif
