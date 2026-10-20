@preconcurrency import ArgmaxCore
import Foundation
import MumlaCore
@preconcurrency import WhisperKit

struct WatchModelFile: Decodable, Sendable {
    let path: String
    let size: Int64
    let sha256: String
    let url: URL
}

/// Networking is confined to install(). Inference uses a verified local model and a local-only tokenizer factory.
struct WatchTranscriber: Sendable {
    let directory: URL
    var isInstalled: Bool { FileManager.default.fileExists(atPath: directory.appendingPathComponent("installed").path) }

    private func manifest() throws -> [WatchModelFile] {
        guard let url = Bundle.main.url(forResource: "WatchModel", withExtension: "json") else { throw VoiceNoteError.invalidNote }
        return try JSONDecoder().decode([WatchModelFile].self, from: Data(contentsOf: url))
    }

    func install(progress: @escaping @Sendable (Double) async -> Void) async throws {
        let files = try manifest()
        let total = Double(files.reduce(0) { $0 + $1.size })
        var complete = 0.0
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        for file in files {
            try Task.checkCancellation()
            let target = directory.appendingPathComponent(file.path)
            if !valid(file) {
                let (temporary, response) = try await session.download(from: file.url)
                defer { try? FileManager.default.removeItem(at: temporary) }
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      (try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) == file.size,
                      try ModelArtifactVerifier.sha256Hex(of: temporary) == file.sha256 else { throw VoiceNoteError.invalidAudio }
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
                try FileManager.default.moveItem(at: temporary, to: target)
            }
            complete += Double(file.size)
            await progress(complete / total)
        }
        try Data().write(to: directory.appendingPathComponent("installed"), options: .atomic)
        var root = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
    }

    func transcribe(audio: URL, language: String) async throws -> String {
        let files = try manifest()
        guard isInstalled, files.allSatisfy(valid) else { throw WatchTranscriptionError.modelMissing }
        try Task.checkCancellation()
        let tokenizerURL = directory.appendingPathComponent("tokenizer")
        let tokenizer = try await AutoTokenizerWrapper.from(modelFolder: tokenizerURL)
        let engine = try await WhisperKit(WhisperKitConfig(
            modelFolder: directory.path,
            computeOptions: ModelComputeOptions(melCompute: .cpuOnly, audioEncoderCompute: .cpuOnly, textDecoderCompute: .cpuOnly),
            verbose: false, prewarm: false, load: false, download: false
        ))
        engine.tokenizer = LocalWatchTokenizer(tokenizer)
        engine.textDecoder.isModelMultilingual = true
        do {
            try await engine.loadModels()
            try Task.checkCancellation()
            let samples = try AudioProcessor.loadAudioAsFloatArray(fromPath: audio.path)
            guard !samples.isEmpty, samples.count <= 16_000 * 61 else { throw VoiceNoteError.invalidAudio }
            let results = try await engine.transcribe(audioArray: samples, decodeOptions: DecodingOptions(
                task: .transcribe, language: language, temperature: 0, temperatureFallbackCount: 0,
                usePrefillPrompt: true, detectLanguage: false, skipSpecialTokens: true,
                wordTimestamps: false, concurrentWorkerCount: 1
            ), callback: { _ in !Task.isCancelled })
            try Task.checkCancellation()
            let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            await engine.unloadModels()
            guard !text.isEmpty else { throw WatchTranscriptionError.noSpeech }
            return text
        } catch {
            await engine.unloadModels()
            throw error
        }
    }

    private func valid(_ file: WatchModelFile) -> Bool {
        let url = directory.appendingPathComponent(file.path)
        return (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) == file.size
            && (try? ModelArtifactVerifier.sha256Hex(of: url)) == file.sha256
    }
}

enum WatchTranscriptionError: Error, LocalizedError {
    case modelMissing, noSpeech
    var errorDescription: String? {
        switch self {
        case .modelMissing: "Download the speech model before transcribing."
        case .noSpeech: "No speech was detected. Your recording is saved."
        }
    }
}

/// WhisperKit's default tokenizer loader can download a fallback. This adapter only reads verified local files.
private final class LocalWatchTokenizer: WhisperTokenizer {
    let base: TokenizerWrapper
    let specialTokens: SpecialTokens
    let allLanguageTokens: Set<Int>

    init(_ base: TokenizerWrapper) {
        self.base = base
        func token(_ name: String, _ fallback: Int) -> Int { base.convertTokenToId(name) ?? fallback }
        specialTokens = SpecialTokens(
            endToken: token("<|endoftext|>", 50257), englishToken: token("<|en|>", 50259),
            noSpeechToken: token("<|nospeech|>", 50362), noTimestampsToken: token("<|notimestamps|>", 50363),
            specialTokenBegin: 50257, startOfPreviousToken: token("<|startofprev|>", 50361),
            startOfTranscriptToken: token("<|startoftranscript|>", 50258), timeTokenBegin: token("<|0.00|>", 50364),
            transcribeToken: token("<|transcribe|>", 50359), translateToken: token("<|translate|>", 50358), whitespaceToken: 220
        )
        allLanguageTokens = Set(Constants.languages.values.compactMap { base.convertTokenToId("<|\($0)|>") })
    }
    func encode(text: String) -> [Int] { base.encode(text: text) }
    func decode(tokens: [Int]) -> String { base.decode(tokens: tokens) }
    func convertTokenToId(_ token: String) -> Int? { base.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { base.convertIdToToken(id) }
    func splitToWordTokens(tokenIds: [Int]) -> (words: [String], wordTokens: [[Int]]) {
        // Word timestamps are disabled. Preserve all text if the runtime requests a grouping.
        ([decode(tokens: tokenIds)], [tokenIds])
    }
}
