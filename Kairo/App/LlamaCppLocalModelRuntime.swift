#if canImport(llama)
import Foundation
import KairoCore
import llama
#if canImport(Darwin)
import Darwin
#endif

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
    _ = seqIDs
    let index = Int(batch.n_tokens)
    batch.token[index] = id
    batch.pos[index] = pos
    batch.logits[index] = logits ? 1 : 0
    batch.n_tokens += 1
}

actor LlamaCppSession {
    #if targetEnvironment(simulator)
    private static let prefillChunkTokenCapacity = 64
    #else
    private static let prefillChunkTokenCapacity = 128
    #endif
    private static let batchTokenCapacity = 512
    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer
    private let sampler: UnsafeMutablePointer<llama_sampler>
    private var batch: llama_batch
    private var position: Int32 = 0
    private var pendingUTF8Bytes: [CChar] = []

    init(modelPath: String, contextLength: UInt32 = 4_096, temperature: Double = 0.2) throws {
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
        batch = llama_batch_init(Int32(Self.batchTokenCapacity), 0, 0)
        batch.n_seq_id = nil
        batch.seq_id = nil

        let samplerParameters = llama_sampler_chain_default_params()
        sampler = llama_sampler_chain_init(samplerParameters)
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(Float(temperature)))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(42))
    }

    deinit {
        llama_sampler_free(sampler)
        llama_batch_free(batch)
        llama_free(context)
        llama_model_free(model)
        llama_backend_free()
    }

    func generate(
        prompt: String,
        maxTokens: Int32,
        resetContext: Bool,
        addBOS: Bool,
        progress: ((AIInferenceMetrics) -> Void)? = nil
    ) throws -> (
        text: String,
        promptTokens: Int,
        generatedTokens: Int,
        promptTokensPerSecond: Double,
        generationTokensPerSecond: Double,
        firstTokenLatencyMS: Double?,
        peakMemoryMB: Int?
    ) {
        if resetContext {
            llama_memory_clear(llama_get_memory(context), true)
            position = 0
        }
        pendingUTF8Bytes.removeAll()
        let startedAt = Date()
        var peakMemoryMB = Self.currentResidentMemoryMB()

        let promptTokens = tokenize(text: prompt, addBOS: addBOS)
        guard !promptTokens.isEmpty else {
            throw LlamaCppRuntimeError.couldNotTokenizePrompt
        }
        let contextSize = llama_n_ctx(context)
        guard Int(position) + promptTokens.count + Int(maxTokens) <= Int(contextSize) else {
            throw LlamaCppRuntimeError.promptTooLarge
        }

        let prefillStartedAt = Date()
        var consumedPromptTokens = 0
        var lastPrefillProgressAt = Date.distantPast
        while consumedPromptTokens < promptTokens.count {
            let chunkEnd = min(consumedPromptTokens + Self.prefillChunkTokenCapacity, promptTokens.count)
            kairo_llama_batch_clear(&batch)
            for tokenIndex in consumedPromptTokens..<chunkEnd {
                let isLastPromptToken = tokenIndex == promptTokens.count - 1
                kairo_llama_batch_add(
                    &batch,
                    promptTokens[tokenIndex],
                    position + Int32(tokenIndex - consumedPromptTokens),
                    [0],
                    isLastPromptToken
                )
            }
            guard llama_decode(context, batch) == 0 else {
                throw LlamaCppRuntimeError.decodeFailed
            }
            peakMemoryMB = Self.maxMemoryMB(peakMemoryMB, Self.currentResidentMemoryMB())
            position += batch.n_tokens
            consumedPromptTokens = chunkEnd
            let now = Date()
            if now.timeIntervalSince(lastPrefillProgressAt) >= 3 || consumedPromptTokens == promptTokens.count {
                let prefillElapsed = max(now.timeIntervalSince(prefillStartedAt), 0.001)
                let promptTokensPerSecond = Double(consumedPromptTokens) / prefillElapsed
                let remainingTokens = max(0, promptTokens.count - consumedPromptTokens)
                let remainingSeconds = promptTokensPerSecond > 0
                    ? Double(remainingTokens) / promptTokensPerSecond
                    : nil
                progress?(AIInferenceMetrics(
                    stage: .prefill,
                    promptTokens: promptTokens.count,
                    promptTokensProcessed: consumedPromptTokens,
                    generatedTokens: 0,
                    promptTokensPerSecond: promptTokensPerSecond,
                    generationTokensPerSecond: nil,
                    promptSecondsRemaining: remainingSeconds
                ))
                lastPrefillProgressAt = now
            }
        }
        let prefillElapsed = max(Date().timeIntervalSince(prefillStartedAt), 0.001)
        let promptTokensPerSecond = Double(promptTokens.count) / prefillElapsed
        var generatedText = ""
        var generatedTokens = 0
        var firstTokenLatencyMS: Double?
        var generationStartedAt: Date?
        var lastProgressTokenCount = 0
        while generatedTokens < Int(maxTokens) {
            let token = llama_sampler_sample(sampler, context, batch.n_tokens - 1)
            let vocabTokenCount = llama_vocab_n_tokens(vocab)
            guard token >= 0, token < vocabTokenCount else {
                throw LlamaCppRuntimeError.decodeFailed
            }
            if llama_vocab_is_eog(vocab, token) {
                break
            }

            if firstTokenLatencyMS == nil {
                firstTokenLatencyMS = Date().timeIntervalSince(startedAt) * 1000.0
                generationStartedAt = Date()
            }
            generatedTokens += 1
            generatedText += decodePiece(token: token)
            if let generationStartedAt,
               generatedTokens - lastProgressTokenCount >= 4 {
                let generationElapsed = max(Date().timeIntervalSince(generationStartedAt), 0.001)
                progress?(AIInferenceMetrics(
                    stage: .generation,
                    promptTokens: promptTokens.count,
                    promptTokensProcessed: promptTokens.count,
                    generatedTokens: generatedTokens,
                    promptTokensPerSecond: promptTokensPerSecond,
                    generationTokensPerSecond: Double(generatedTokens) / generationElapsed,
                    promptSecondsRemaining: 0
                ))
                lastProgressTokenCount = generatedTokens
            }
            if generatedText.contains("<|im_end|>") {
                break
            }

            kairo_llama_batch_clear(&batch)
            kairo_llama_batch_add(&batch, token, position, [0], true)
            guard llama_decode(context, batch) == 0 else {
                throw LlamaCppRuntimeError.decodeFailed
            }
            peakMemoryMB = Self.maxMemoryMB(peakMemoryMB, Self.currentResidentMemoryMB())
            position += 1
        }

        let trimmed = generatedText
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LlamaCppRuntimeError.emptyResponse
        }
        let generationElapsed = max(Date().timeIntervalSince(generationStartedAt ?? startedAt), 0.001)
        progress?(AIInferenceMetrics(
            stage: .complete,
            promptTokens: promptTokens.count,
            promptTokensProcessed: promptTokens.count,
            generatedTokens: generatedTokens,
            promptTokensPerSecond: promptTokensPerSecond,
            generationTokensPerSecond: Double(generatedTokens) / generationElapsed,
            promptSecondsRemaining: 0
        ))
        return (
            trimmed,
            promptTokens.count,
            generatedTokens,
            promptTokensPerSecond,
            Double(generatedTokens) / generationElapsed,
            firstTokenLatencyMS,
            peakMemoryMB
        )
    }

    private static func maxMemoryMB(_ lhs: Int?, _ rhs: Int?) -> Int? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return max(lhs, rhs)
        case let (.some(value), .none), let (.none, .some(value)):
            return value
        case (.none, .none):
            return nil
        }
    }

    private static func currentResidentMemoryMB() -> Int? {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Int((Double(info.resident_size) / 1_048_576.0).rounded())
        #else
        return nil
        #endif
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
    private static let sessionPool = LlamaCppSessionPool()

    func generateReply(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        parameters: LocalModelRuntimeParameters
    ) async throws -> LocalModelReplyCheckResult {
        let clampedParameters = parameters.clamped(to: model)
        let session = try LlamaCppSession(
            modelPath: installRecord.fileURL.path,
            contextLength: UInt32(max(clampedParameters.contextSize, 1)),
            temperature: clampedParameters.temperature
        )
        let preparedPrompt = Self.preparedPrompt(prompt, for: model)
        let output = try await session.generate(
            prompt: preparedPrompt.text,
            maxTokens: Int32(max(1, clampedParameters.maxOutputTokens)),
            resetContext: true,
            addBOS: preparedPrompt.addBOS
        )

        return LocalModelReplyCheckResult(
            modelID: model.id,
            modelDisplayName: model.displayName,
            runtime: .gguf,
            runtimePackage: "llama.cpp iOS",
            prompt: preparedPrompt.text,
            responseText: output.text,
            promptTokens: output.promptTokens,
            generatedTokens: output.generatedTokens,
            promptTokensPerSecond: output.promptTokensPerSecond,
            generationTokensPerSecond: output.generationTokensPerSecond,
            measuredAt: Date(),
            notes: "Generated in KairoApp through embedded llama.xcframework."
        )
    }

    func runBenchmark(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        generatedTokenTarget: Int,
        contextSize: Int
    ) async throws -> LocalModelBenchmarkRunResult {
        let session = try LlamaCppSession(modelPath: installRecord.fileURL.path, contextLength: UInt32(max(contextSize, 1)))
        let preparedPrompt = Self.preparedPrompt(prompt, for: model)
        let output = try await session.generate(
            prompt: preparedPrompt.text,
            maxTokens: Int32(generatedTokenTarget),
            resetContext: true,
            addBOS: preparedPrompt.addBOS
        )

        return LocalModelBenchmarkRunResult(
            id: "\(model.id)-ios-llama-\(Int(Date().timeIntervalSince1970))",
            modelID: model.id,
            modelDisplayName: model.displayName,
            runtime: .gguf,
            runtimePackage: "llama.cpp iOS",
            promptTokens: output.promptTokens,
            generatedTokens: output.generatedTokens,
            promptTokensPerSecond: output.promptTokensPerSecond,
            generationTokensPerSecond: output.generationTokensPerSecond,
            firstTokenLatencyMS: output.firstTokenLatencyMS,
            peakMemoryMB: output.peakMemoryMB,
            measuredAt: Date(),
            isReferenceOnlyForIOS: false,
            notes: "Generated \(output.generatedTokens) tokens through embedded llama.xcframework."
        )
    }

    private static func preparedPrompt(
        _ prompt: String,
        for model: LocalModelManifest
    ) -> (text: String, addBOS: Bool) {
        guard model.usesQwenChatTemplate else {
            return (prompt, true)
        }
        return (qwenChatPrompt(from: prompt), false)
    }

    private static func qwenChatPrompt(from prompt: String) -> String {
        let cleanedPrompt = prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingSuffix("Assistant:")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sections = qwenPromptSections(from: cleanedPrompt)
        return """
        <|im_start|>system
        \(sections.system)
        <|im_end|>
        <|im_start|>user
        \(sections.user)
        <|im_end|>
        <|im_start|>assistant

        """
    }

    private static func qwenPromptSections(from prompt: String) -> (system: String, user: String) {
        guard let userRange = prompt.range(of: "\nUser:\n", options: .backwards) else {
            return (prompt, prompt)
        }
        let system = String(prompt[..<userRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let afterUser = prompt[userRange.upperBound...]
        let user: String
        if let assistantRange = afterUser.range(of: "\n\nAssistant:", options: .backwards) {
            user = String(afterUser[..<assistantRange.lowerBound])
        } else {
            user = String(afterUser)
        }
        return (
            system.isEmpty ? "You are Kairo. Answer directly and concisely." : system,
            user.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

extension LlamaCppLocalModelRuntime: LocalModelConversationalReplyRuntime {
    func generateReply(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        initialPrompt: String,
        turnPrompt: String,
        conversationKey: LocalModelConversationRuntimeKey,
        parameters: LocalModelRuntimeParameters
    ) async throws -> LocalModelReplyCheckResult {
        let clampedParameters = parameters.clamped(to: model)
        await AIInferenceProgressCenter.shared.publish(AIInferenceProgressSnapshot(
            conversationID: conversationKey.conversationID,
            metrics: AIInferenceMetrics(stage: .loadingModel)
        ))
        let pooledSession = try await Self.sessionPool.session(
            for: conversationKey,
            modelPath: installRecord.fileURL.path,
            contextLength: UInt32(max(clampedParameters.contextSize, 1)),
            temperature: clampedParameters.temperature
        )
        let prompt = pooledSession.isNew ? initialPrompt : turnPrompt
        let preparedPrompt = Self.preparedPrompt(prompt, for: model)
        let output = try await pooledSession.session.generate(
            prompt: preparedPrompt.text,
            maxTokens: Int32(max(1, clampedParameters.maxOutputTokens)),
            resetContext: pooledSession.isNew,
            addBOS: pooledSession.isNew && preparedPrompt.addBOS,
            progress: { metrics in
                Task {
                    await AIInferenceProgressCenter.shared.publish(AIInferenceProgressSnapshot(
                        conversationID: conversationKey.conversationID,
                        metrics: metrics
                    ))
                }
            }
        )

        return LocalModelReplyCheckResult(
            modelID: model.id,
            modelDisplayName: model.displayName,
            runtime: .gguf,
            runtimePackage: "llama.cpp iOS",
            prompt: preparedPrompt.text,
            responseText: output.text,
            promptTokens: output.promptTokens,
            generatedTokens: output.generatedTokens,
            promptTokensPerSecond: output.promptTokensPerSecond,
            generationTokensPerSecond: output.generationTokensPerSecond,
            measuredAt: Date(),
            notes: pooledSession.isNew
                ? "Generated in a new Kairo local conversation session."
                : "Generated by appending to an existing Kairo local conversation session."
        )
    }
}

private extension LocalModelManifest {
    var usesQwenChatTemplate: Bool {
        let probe = "\(id) \(displayName) \(family)".lowercased()
        return probe.contains("qwen")
    }
}

private extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }
}

private struct PooledLlamaCppSession: Sendable {
    var session: LlamaCppSession
    var isNew: Bool
}

private actor LlamaCppSessionPool {
    private var sessions: [LocalModelConversationRuntimeKey: LlamaCppSession] = [:]
    private var mostRecentKeys: [LocalModelConversationRuntimeKey] = []
    private let maxSessionCount = 3

    func session(
        for key: LocalModelConversationRuntimeKey,
        modelPath: String,
        contextLength: UInt32,
        temperature: Double
    ) throws -> PooledLlamaCppSession {
        if let session = sessions[key] {
            touch(key)
            return PooledLlamaCppSession(session: session, isNew: false)
        }

        let session = try LlamaCppSession(
            modelPath: modelPath,
            contextLength: contextLength,
            temperature: temperature
        )
        sessions[key] = session
        touch(key)
        trimIfNeeded()
        return PooledLlamaCppSession(session: session, isNew: true)
    }

    private func touch(_ key: LocalModelConversationRuntimeKey) {
        mostRecentKeys.removeAll { $0 == key }
        mostRecentKeys.insert(key, at: 0)
    }

    private func trimIfNeeded() {
        while mostRecentKeys.count > maxSessionCount, let key = mostRecentKeys.popLast() {
            sessions[key] = nil
        }
    }
}
#endif
