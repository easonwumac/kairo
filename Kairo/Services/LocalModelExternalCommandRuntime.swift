import Foundation

public struct LocalModelCommandRunResult: Equatable, Sendable {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32
    public var durationSeconds: Double

    public init(stdout: String, stderr: String, exitCode: Int32, durationSeconds: Double) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.durationSeconds = durationSeconds
    }
}

public enum LocalModelCommandRunnerError: Error, Equatable, Sendable {
    case executableNotFound(String)
    case timedOut(Double)
    case launchFailed(String)

    public var userMessage: String {
        switch self {
        case let .executableNotFound(path):
            return "Local model CLI was not found or is not executable at \(path)."
        case let .timedOut(timeout):
            return "Local model CLI timed out after \(Int(timeout)) seconds."
        case let .launchFailed(message):
            return "Local model CLI failed to launch: \(message)"
        }
    }
}

public protocol LocalModelCommandRunner: Sendable {
    func run(
        executableURL: URL,
        arguments: [String],
        timeoutSeconds: Double
    ) async throws -> LocalModelCommandRunResult
}

public enum LocalModelCommandTool: String, Codable, Equatable, Sendable {
    case llamaCLI
    case mlxLMGenerate
}

public struct LocalModelCommandRuntimeConfiguration: Equatable, Sendable {
    public var tool: LocalModelCommandTool
    public var executableURL: URL
    public var runtime: LocalModelRuntime
    public var runtimePackage: String
    public var timeoutSeconds: Double
    public var defaultGeneratedTokenTarget: Int
    public var modelReferenceOverride: String?

    public init(
        tool: LocalModelCommandTool,
        executableURL: URL,
        runtime: LocalModelRuntime,
        runtimePackage: String,
        timeoutSeconds: Double = 120,
        defaultGeneratedTokenTarget: Int = 64,
        modelReferenceOverride: String? = nil
    ) {
        self.tool = tool
        self.executableURL = executableURL
        self.runtime = runtime
        self.runtimePackage = runtimePackage
        self.timeoutSeconds = timeoutSeconds
        self.defaultGeneratedTokenTarget = defaultGeneratedTokenTarget
        self.modelReferenceOverride = modelReferenceOverride
    }

    public static func llamaCLI(
        executableURL: URL,
        timeoutSeconds: Double = 120,
        defaultGeneratedTokenTarget: Int = 64
    ) -> LocalModelCommandRuntimeConfiguration {
        LocalModelCommandRuntimeConfiguration(
            tool: .llamaCLI,
            executableURL: executableURL,
            runtime: .gguf,
            runtimePackage: "llama.cpp CLI",
            timeoutSeconds: timeoutSeconds,
            defaultGeneratedTokenTarget: defaultGeneratedTokenTarget
        )
    }

    public static func mlxLMGenerate(
        pythonExecutableURL: URL,
        modelReferenceOverride: String? = nil,
        timeoutSeconds: Double = 120,
        defaultGeneratedTokenTarget: Int = 64
    ) -> LocalModelCommandRuntimeConfiguration {
        LocalModelCommandRuntimeConfiguration(
            tool: .mlxLMGenerate,
            executableURL: pythonExecutableURL,
            runtime: .mlx,
            runtimePackage: "mlx-lm",
            timeoutSeconds: timeoutSeconds,
            defaultGeneratedTokenTarget: defaultGeneratedTokenTarget,
            modelReferenceOverride: modelReferenceOverride
        )
    }

    public func commandArguments(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        generatedTokenTarget: Int
    ) -> [String] {
        let maxTokens = String(max(generatedTokenTarget, 1))
        switch tool {
        case .llamaCLI:
            return [
                "-m",
                installRecord.fileURL.path,
                "-p",
                prompt,
                "-n",
                maxTokens,
                "--no-display-prompt"
            ]
        case .mlxLMGenerate:
            return [
                "-m",
                "mlx_lm.generate",
                "--model",
                modelReference(for: model, installRecord: installRecord),
                "--prompt",
                prompt,
                "--max-tokens",
                maxTokens
            ]
        }
    }

    private func modelReference(for model: LocalModelManifest, installRecord: LocalModelInstallRecord) -> String {
        if let modelReferenceOverride, !modelReferenceOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return modelReferenceOverride
        }
        if let mlxProfile = model.benchmarkProfiles.first(where: { $0.runtime == .mlx }) {
            return mlxProfile.artifactReference
        }
        return installRecord.fileURL.path
    }
}

public struct LocalModelExternalCommandRuntime: LocalModelReplyCheckRuntime, LocalModelBenchmarkEngine {
    private let configuration: LocalModelCommandRuntimeConfiguration
    private let commandRunner: any LocalModelCommandRunner

    public init(
        configuration: LocalModelCommandRuntimeConfiguration,
        commandRunner: any LocalModelCommandRunner
    ) {
        self.configuration = configuration
        self.commandRunner = commandRunner
    }

    public func generateReply(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        parameters: LocalModelRuntimeParameters
    ) async throws -> LocalModelReplyCheckResult {
        _ = parameters
        do {
            let output = try await run(model: model, installRecord: installRecord, prompt: prompt)
            return LocalModelReplyCheckResult(
                modelID: model.id,
                modelDisplayName: model.displayName,
                runtime: configuration.runtime,
                runtimePackage: configuration.runtimePackage,
                prompt: prompt,
                responseText: output.responseText,
                generatedTokens: output.generatedTokens,
                generationTokensPerSecond: output.generationTokensPerSecond,
                measuredAt: Date(),
                notes: "Generated through \(configuration.runtimePackage). Model file or model reference is user-provided; Kairo does not bundle weights."
            )
        } catch {
            throw LocalModelReplyCheckError.runtimeUnavailable(Self.userMessage(for: error))
        }
    }

    public func runBenchmark(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        generatedTokenTarget: Int,
        contextSize: Int
    ) async throws -> LocalModelBenchmarkRunResult {
        do {
            let output = try await run(
                model: model,
                installRecord: installRecord,
                prompt: prompt,
                generatedTokenTarget: generatedTokenTarget
            )
            let measuredAt = Date()
            return LocalModelBenchmarkRunResult(
                id: "\(model.id)-\(configuration.tool.rawValue)-\(Int(measuredAt.timeIntervalSince1970))",
                modelID: model.id,
                modelDisplayName: model.displayName,
                runtime: configuration.runtime,
                runtimePackage: configuration.runtimePackage,
                promptTokens: output.promptTokens,
                generatedTokens: output.generatedTokens,
                promptTokensPerSecond: output.promptTokensPerSecond,
                generationTokensPerSecond: output.generationTokensPerSecond,
                measuredAt: measuredAt,
                isReferenceOnlyForIOS: configuration.runtime == .mlx,
                notes: "Measured through \(configuration.runtimePackage). Treat macOS CLI runs as development evidence until iPhone runtime is wired and measured."
            )
        } catch {
            throw LocalModelBenchmarkError.runtimeUnavailable(Self.userMessage(for: error))
        }
    }

    private func run(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        generatedTokenTarget: Int? = nil
    ) async throws -> ParsedLocalModelCommandOutput {
        let maxTokens = generatedTokenTarget ?? configuration.defaultGeneratedTokenTarget
        let result = try await commandRunner.run(
            executableURL: configuration.executableURL,
            arguments: configuration.commandArguments(
                model: model,
                installRecord: installRecord,
                prompt: prompt,
                generatedTokenTarget: maxTokens
            ),
            timeoutSeconds: configuration.timeoutSeconds
        )

        guard result.exitCode == 0 else {
            throw LocalModelExternalCommandRuntimeError.commandFailed(
                exitCode: result.exitCode,
                stderr: String(result.stderr.prefix(400))
            )
        }

        let responseText = Self.responseText(from: result.stdout)
        guard !responseText.isEmpty else {
            throw LocalModelExternalCommandRuntimeError.emptyResponse
        }

        let metrics = Self.metrics(
            stdout: result.stdout,
            stderr: result.stderr,
            prompt: prompt,
            responseText: responseText,
            durationSeconds: result.durationSeconds
        )
        return ParsedLocalModelCommandOutput(
            responseText: responseText,
            promptTokens: metrics.promptTokens,
            generatedTokens: metrics.generatedTokens,
            promptTokensPerSecond: metrics.promptTokensPerSecond,
            generationTokensPerSecond: metrics.generationTokensPerSecond
        )
    }

    private static func responseText(from stdout: String) -> String {
        stdout
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return false }
                return !isMetricLine(trimmed)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func metrics(
        stdout: String,
        stderr: String,
        prompt: String,
        responseText: String,
        durationSeconds: Double
    ) -> ParsedLocalModelCommandMetrics {
        let combinedOutput = [stdout, stderr].joined(separator: "\n")
        let promptMetric = metric(
            in: combinedOutput,
            labels: ["prompt eval", "prompt"]
        )
        let generationMetric = metric(
            in: combinedOutput,
            labels: ["generation", "generated", "eval time", "eval"],
            excludingPromptLines: true
        )
        let safeDuration = max(durationSeconds, 0.001)
        let promptTokens = promptMetric?.tokens ?? estimatedTokenCount(prompt)
        let generatedTokens = generationMetric?.tokens ?? estimatedTokenCount(responseText)

        return ParsedLocalModelCommandMetrics(
            promptTokens: promptTokens,
            generatedTokens: generatedTokens,
            promptTokensPerSecond: promptMetric?.tokensPerSecond ?? Double(promptTokens) / safeDuration,
            generationTokensPerSecond: generationMetric?.tokensPerSecond ?? Double(generatedTokens) / safeDuration
        )
    }

    private static func metric(
        in text: String,
        labels: [String],
        excludingPromptLines: Bool = false
    ) -> ParsedLocalModelCommandMetric? {
        let searchableText = text
            .components(separatedBy: .newlines)
            .filter { line in
                !excludingPromptLines || !line.lowercased().contains("prompt")
            }
            .joined(separator: "\n")
        for label in labels {
            let escapedLabel = NSRegularExpression.escapedPattern(for: label)
            let pattern = "\(escapedLabel)[^\\n]*?(\\d+)\\s*(?:tokens|token|tok|runs)[^\\n]*?([0-9]+(?:\\.[0-9]+)?)\\s*(?:tokens per second|tokens-per-sec|tokens/s|tok/s)"
            if let metric = firstMetric(in: searchableText, pattern: pattern) {
                return metric
            }
        }
        return nil
    }

    private static func firstMetric(in text: String, pattern: String) -> ParsedLocalModelCommandMetric? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 3,
              let tokensRange = Range(match.range(at: 1), in: text),
              let rateRange = Range(match.range(at: 2), in: text),
              let tokens = Int(text[tokensRange]),
              let rate = Double(text[rateRange])
        else {
            return nil
        }
        return ParsedLocalModelCommandMetric(tokens: tokens, tokensPerSecond: rate)
    }

    private static func isMetricLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.contains("tokens per second")
            || lowercased.contains("tokens-per-sec")
            || lowercased.contains("tok/s")
            || lowercased.contains("llama_perf")
    }

    private static func estimatedTokenCount(_ text: String) -> Int {
        let words = text.split { character in
            character.isWhitespace || character.isPunctuation
        }
        if !words.isEmpty {
            return words.count
        }
        return max(text.count / 4, 1)
    }

    private static func userMessage(for error: Error) -> String {
        if let runnerError = error as? LocalModelCommandRunnerError {
            return runnerError.userMessage
        }
        if let commandError = error as? LocalModelExternalCommandRuntimeError {
            return commandError.userMessage
        }
        return String(describing: error)
    }
}

private struct ParsedLocalModelCommandOutput: Equatable, Sendable {
    var responseText: String
    var promptTokens: Int
    var generatedTokens: Int
    var promptTokensPerSecond: Double
    var generationTokensPerSecond: Double
}

private struct ParsedLocalModelCommandMetrics: Equatable, Sendable {
    var promptTokens: Int
    var generatedTokens: Int
    var promptTokensPerSecond: Double
    var generationTokensPerSecond: Double
}

private struct ParsedLocalModelCommandMetric: Equatable, Sendable {
    var tokens: Int
    var tokensPerSecond: Double
}

private enum LocalModelExternalCommandRuntimeError: Error, Equatable, Sendable {
    case commandFailed(exitCode: Int32, stderr: String)
    case emptyResponse

    var userMessage: String {
        switch self {
        case let .commandFailed(exitCode, stderr):
            return "Local model CLI exited with \(exitCode): \(stderr)"
        case .emptyResponse:
            return "Local model CLI returned an empty response."
        }
    }
}

#if os(macOS)
public struct ProcessLocalModelCommandRunner: LocalModelCommandRunner {
    public init() {}

    public func run(
        executableURL: URL,
        arguments: [String],
        timeoutSeconds: Double
    ) async throws -> LocalModelCommandRunResult {
        try await Task.detached(priority: .userInitiated) {
            try runProcess(
                executableURL: executableURL,
                arguments: arguments,
                timeoutSeconds: timeoutSeconds
            )
        }.value
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String],
        timeoutSeconds: Double
    ) throws -> LocalModelCommandRunResult {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw LocalModelCommandRunnerError.executableNotFound(executableURL.path)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let startedAt = Date()
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        do {
            try process.run()
        } catch {
            throw LocalModelCommandRunnerError.launchFailed(error.localizedDescription)
        }

        let timeout = DispatchTime.now() + timeoutSeconds
        if semaphore.wait(timeout: timeout) == .timedOut {
            process.terminate()
            throw LocalModelCommandRunnerError.timedOut(timeoutSeconds)
        }

        let stdout = String(
            data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let stderr = String(
            data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return LocalModelCommandRunResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus,
            durationSeconds: Date().timeIntervalSince(startedAt)
        )
    }
}
#endif
