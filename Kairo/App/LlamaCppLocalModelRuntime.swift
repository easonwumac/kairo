#if canImport(llama)
import Foundation
import KairoCore
import llama

enum LlamaCppRuntimeError: LocalizedError {
    case couldNotLoadModel(String)
    case couldNotCreateContext
    case couldNotTokenizePrompt
    case promptTooLarge
    case decodeFailed
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case let .couldNotLoadModel(path):
            return KairoL10n.string("localModel.llama.error.couldNotLoadModel", path)
        case .couldNotCreateContext:
            return KairoL10n.string("localModel.llama.error.couldNotCreateContext")
        case .couldNotTokenizePrompt:
            return KairoL10n.string("localModel.llama.error.couldNotTokenizePrompt")
        case .promptTooLarge:
            return KairoL10n.string("localModel.llama.error.promptTooLarge")
        case .decodeFailed:
            return KairoL10n.string("localModel.llama.error.decodeFailed")
        case .emptyResponse:
            return KairoL10n.string("localModel.llama.error.emptyResponse")
        }
    }
}

private func kairo_llama_batch_clear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}

private func kairo_llama_batch_add(
    _ batch: inout llama_batch,
    _ id: llama_token,
    _ pos: llama_pos,
    _ seqIDs: [llama_seq_id],
    _ logits: Bool
) {
    let index = Int(batch.n_tokens)
    batch.token[index] = id
    batch.pos[index] = pos
    batch.n_seq_id[index] = Int32(seqIDs.count)
    for seqIndex in 0..<seqIDs.count {
        batch.seq_id[index]![seqIndex] = seqIDs[seqIndex]
    }
    batch.logits[index] = logits ? 1 : 0
    batch.n_tokens += 1
}

actor LlamaCppSession {
    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer
    private let sampler: UnsafeMutablePointer<llama_sampler>
    private var batch: llama_batch
    private var position: Int32 = 0
    private var pendingUTF8Bytes: [CChar] = []

    init(modelPath: String, contextLength: UInt32 = 4_096) throws {
        llama_backend_init()
        var modelParameters = llama_model_default_params()
        #if targetEnvironment(simulator)
        modelParameters.n_gpu_layers = 0
        #endif
        guard let loadedModel = llama_model_load_from_file(modelPath, modelParameters) else {
            throw LlamaCppRuntimeError.couldNotLoadModel(modelPath)
        }
        model = loadedModel

        var contextParameters = llama_context_default_params()
        let threadCount = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        contextParameters.n_ctx = contextLength
        contextParameters.n_threads = Int32(threadCount)
        contextParameters.n_threads_batch = Int32(threadCount)
        guard let loadedContext = llama_init_from_model(model, contextParameters) else {
            llama_model_free(model)
            llama_backend_free()
            throw LlamaCppRuntimeError.couldNotCreateContext
        }
        context = loadedContext
        vocab = llama_model_get_vocab(model)
        batch = llama_batch_init(512, 0, 1)

        let samplerParameters = llama_sampler_chain_default_params()
        sampler = llama_sampler_chain_init(samplerParameters)
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.2))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(42))
    }

    deinit {
        llama_sampler_free(sampler)
        llama_batch_free(batch)
        llama_free(context)
        llama_model_free(model)
        llama_backend_free()
    }

    func generate(prompt: String, maxTokens: Int32) throws -> (text: String, generatedTokens: Int) {
        llama_memory_clear(llama_get_memory(context), true)
        pendingUTF8Bytes.removeAll()
        position = 0

        let promptTokens = tokenize(text: prompt, addBOS: true)
        guard !promptTokens.isEmpty else {
            throw LlamaCppRuntimeError.couldNotTokenizePrompt
        }
        let contextSize = llama_n_ctx(context)
        guard promptTokens.count + Int(maxTokens) <= Int(contextSize) else {
            throw LlamaCppRuntimeError.promptTooLarge
        }

        kairo_llama_batch_clear(&batch)
        for tokenIndex in 0..<promptTokens.count {
            kairo_llama_batch_add(&batch, promptTokens[tokenIndex], Int32(tokenIndex), [0], false)
        }
        batch.logits[Int(batch.n_tokens) - 1] = 1
        guard llama_decode(context, batch) == 0 else {
            throw LlamaCppRuntimeError.decodeFailed
        }
        position = batch.n_tokens

        var generatedText = ""
        var generatedTokens = 0
        while generatedTokens < Int(maxTokens) {
            let token = llama_sampler_sample(sampler, context, batch.n_tokens - 1)
            if llama_vocab_is_eog(vocab, token) {
                break
            }

            generatedTokens += 1
            generatedText += decodePiece(token: token)

            kairo_llama_batch_clear(&batch)
            kairo_llama_batch_add(&batch, token, position, [0], true)
            guard llama_decode(context, batch) == 0 else {
                throw LlamaCppRuntimeError.decodeFailed
            }
            position += 1
        }

        let trimmed = generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LlamaCppRuntimeError.emptyResponse
        }
        return (trimmed, generatedTokens)
    }

    private func tokenize(text: String, addBOS: Bool) -> [llama_token] {
        let utf8Count = text.utf8.count
        let tokenCapacity = utf8Count + (addBOS ? 1 : 0) + 1
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: tokenCapacity)
        defer { tokens.deallocate() }

        let tokenCount = llama_tokenize(vocab, text, Int32(utf8Count), tokens, Int32(tokenCapacity), addBOS, false)
        guard tokenCount > 0 else { return [] }
        return (0..<Int(tokenCount)).map { tokens[$0] }
    }

    private func decodePiece(token: llama_token) -> String {
        let initialCapacity = 8
        let initial = UnsafeMutablePointer<CChar>.allocate(capacity: initialCapacity)
        initial.initialize(repeating: 0, count: initialCapacity)
        defer { initial.deallocate() }

        let pieceLength = llama_token_to_piece(vocab, token, initial, Int32(initialCapacity), 0, false)
        let bytes: [CChar]
        if pieceLength < 0 {
            let requiredCapacity = Int(-pieceLength)
            let expanded = UnsafeMutablePointer<CChar>.allocate(capacity: requiredCapacity)
            expanded.initialize(repeating: 0, count: requiredCapacity)
            defer { expanded.deallocate() }
            let expandedLength = llama_token_to_piece(vocab, token, expanded, Int32(requiredCapacity), 0, false)
            bytes = Array(UnsafeBufferPointer(start: expanded, count: max(0, Int(expandedLength))))
        } else {
            bytes = Array(UnsafeBufferPointer(start: initial, count: Int(pieceLength)))
        }

        pendingUTF8Bytes.append(contentsOf: bytes)
        if let text = String(validatingUTF8: pendingUTF8Bytes + [0]) {
            pendingUTF8Bytes.removeAll()
            return text
        }
        return ""
    }
}

struct LlamaCppLocalModelRuntime: LocalModelReplyCheckRuntime, LocalModelBenchmarkEngine {
    private let generatedTokenLimit: Int32

    init(generatedTokenLimit: Int32 = 64) {
        self.generatedTokenLimit = generatedTokenLimit
    }

    func generateReply(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String
    ) async throws -> LocalModelReplyCheckResult {
        let startedAt = Date()
        let session = try LlamaCppSession(modelPath: installRecord.fileURL.path)
        let output = try await session.generate(prompt: prompt, maxTokens: generatedTokenLimit)
        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)

        return LocalModelReplyCheckResult(
            modelID: model.id,
            modelDisplayName: model.displayName,
            runtime: .gguf,
            runtimePackage: "llama.cpp iOS",
            prompt: prompt,
            responseText: output.text,
            generatedTokens: output.generatedTokens,
            generationTokensPerSecond: Double(output.generatedTokens) / elapsed,
            measuredAt: Date(),
            notes: "Generated in KairoApp through embedded llama.xcframework."
        )
    }

    func runBenchmark(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        generatedTokenTarget: Int
    ) async throws -> LocalModelBenchmarkRunResult {
        let startedAt = Date()
        let session = try LlamaCppSession(modelPath: installRecord.fileURL.path)
        let output = try await session.generate(prompt: prompt, maxTokens: Int32(generatedTokenTarget))
        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
        let generationRate = Double(output.generatedTokens) / elapsed

        return LocalModelBenchmarkRunResult(
            id: "\(model.id)-ios-llama-\(Int(Date().timeIntervalSince1970))",
            modelID: model.id,
            modelDisplayName: model.displayName,
            runtime: .gguf,
            runtimePackage: "llama.cpp iOS",
            promptTokens: max(1, prompt.count / 4),
            generatedTokens: output.generatedTokens,
            promptTokensPerSecond: 0,
            generationTokensPerSecond: generationRate,
            measuredAt: Date(),
            isReferenceOnlyForIOS: false,
            notes: "Generated \(output.generatedTokens) tokens through embedded llama.xcframework."
        )
    }
}
#endif
