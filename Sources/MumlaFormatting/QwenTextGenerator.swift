#if os(macOS)
import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MumlaCore
import Tokenizers

actor QwenTextGenerator {
    enum Action: Sendable { case format, summary }
    static let maximumContextTokens = 8_192
    private let store: QwenModelStore
    private var generating = false
    private var loadedModel: ModelContainer?

    init(store: QwenModelStore) { self.store = store }

    static var supportsDevice: Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }

    func generate(_ request: LocalTextGenerationRequest, action: Action) async throws -> String {
        guard Self.supportsDevice else { throw QwenModelError.unsupportedDevice }
        guard !generating else { throw QwenModelError.busy }
        generating = true
        defer {
            // Retain one weight set, but release temporary inference buffers after every request.
            MLX.Stream.gpu.synchronize()
            MLX.Stream.cpu.synchronize()
            Memory.clearCache()
            generating = false
        }
        try Task.checkCancellation()
        guard store.isInstalled else { throw QwenModelError.invalidFiles }
        try store.verify()
        try Task.checkCancellation()
        Memory.cacheLimit = 64 * 1_024 * 1_024
        return try await run(request, action: action)
    }

    func removeModel() throws {
        guard !generating else { throw QwenModelError.busy }
        loadedModel = nil
        MLX.Stream.gpu.synchronize()
        MLX.Stream.cpu.synchronize()
        Memory.clearCache()
        try store.remove()
    }

    static func prompt(_ request: LocalTextGenerationRequest) throws -> String {
        // Preserve JSON values while preventing user text from becoming chat control tokens.
        try request.prompt().replacingOccurrences(of: "<", with: "\\u003C")
    }

    private func run(_ request: LocalTextGenerationRequest, action: Action) async throws -> String {
        let instructions = action == .format
            ? LocalTranscriptFormatter.formattingInstructions(language: request.language)
            : LocalTranscriptSummarizer.summaryInstructions(language: request.language)
        let prompt = try Self.prompt(request)
        let tokenizer: any MLXLMCommon.Tokenizer
        if let loadedModel { tokenizer = await loadedModel.tokenizer }
        else { tokenizer = try await QwenTokenizerLoader().load(from: store.directory) }
        let outputLimit = action == .format ? 1_536 : 512
        let messages: [[String: any Sendable]] = [
            ["role": "system", "content": instructions], ["role": "user", "content": prompt]
        ]
        let input = try tokenizer.applyChatTemplate(messages: messages, tools: nil,
                                                     additionalContext: ["enable_thinking": false])
        guard input.count + outputLimit <= Self.maximumContextTokens else {
            throw LocalTextGenerationError.inputTooLong
        }
        try Task.checkCancellation()
        let container: ModelContainer
        if let loadedModel { container = loadedModel }
        else {
            container = try await LLMModelFactory.shared.loadContainer(from: store.directory,
                using: QwenTokenizerLoader(cached: tokenizer))
            loadedModel = container
        }
        try Task.checkCancellation()
        // Own and await the worker directly. Never retain chat history between previews.
        return try await container.perform { context in
            let iterator = try TokenIterator(input: LMInput(tokens: MLXArray(input)), model: context.model,
                parameters: GenerateParameters(maxTokens: outputLimit, temperature: 0))
            let (events, worker) = generateTask(promptTokenCount: input.count,
                modelConfiguration: context.configuration, tokenizer: context.tokenizer, iterator: iterator)
            return try await withTaskCancellationHandler {
                do {
                    var output = ""
                    var completed = false
                    for await event in events {
                        try Task.checkCancellation()
                        switch event {
                        case .chunk(let chunk):
                            output += chunk
                            let limit = action == .format ? request.text.count * 2 + 32 : LocalTextPreferences.maximumSummaryCharacters
                            guard output.count <= limit else { throw LocalTextGenerationError.incompleteOutput }
                        case .info(let info):
                            completed = info.stopReason == .stop
                        case .toolCall, .rejectedToolCall:
                            throw LocalTextGenerationError.incompleteOutput
                        }
                    }
                    try Task.checkCancellation()
                    guard completed, !output.contains("<think>"), !output.contains("</think>") else {
                        throw LocalTextGenerationError.incompleteOutput
                    }
                    await worker.value
                    return output
                } catch {
                    worker.cancel()
                    await worker.value
                    throw error
                }
            } onCancel: {
                worker.cancel()
            }
        }
    }
}

private struct QwenTokenizerLoader: MLXLMCommon.TokenizerLoader {
    var cached: (any MLXLMCommon.Tokenizer)?
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        if let cached { return cached }
        let tokenizer = try await AutoTokenizer.from(modelFolder: directory)
        let template = try String(contentsOf: directory.appendingPathComponent("chat_template.jinja"), encoding: .utf8)
        return QwenTokenizer(base: tokenizer, template: template)
    }
}

private struct QwenTokenizer: MLXLMCommon.Tokenizer {
    let base: any Tokenizers.Tokenizer
    let template: String
    var bosToken: String? { base.bosToken }
    var eosToken: String? { base.eosToken }
    var unknownToken: String? { base.unknownToken }
    func encode(text: String, addSpecialTokens: Bool) -> [Int] { base.encode(text: text, addSpecialTokens: addSpecialTokens) }
    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String { base.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens) }
    func convertTokenToId(_ token: String) -> Int? { base.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { base.convertIdToToken(id) }
    func applyChatTemplate(messages: [[String: any Sendable]], tools: [[String: any Sendable]]?,
                           additionalContext: [String: any Sendable]?) throws -> [Int] {
        try base.applyChatTemplate(messages: messages, chatTemplate: .literal(template), addGenerationPrompt: true,
                                   truncation: false, maxLength: nil, tools: tools, additionalContext: additionalContext)
    }
}
#endif
