import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let kairoOmlxLogFileURL: URL = {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("KairoUITesting", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("omlx-cloud.log")
}()

private func kairoOmlxLog(_ message: String) {
    let line = "[\(Date())] \(message)\n"
    print("[KAIRO_OMLX] \(message)")
    fflush(stdout)
    if let data = line.data(using: .utf8) {
        if let fh = try? FileHandle(forUpdating: kairoOmlxLogFileURL) {
            _ = try? fh.seekToEnd()
            try? fh.write(contentsOf: data)
            try? fh.close()
        } else {
            try? data.write(to: kairoOmlxLogFileURL, options: .atomic)
        }
    }
}

public struct OpenAICompatibleProvider: AIProvider {
    private let credentialStore: CredentialStore
    private let httpClient: HTTPClient
    private let baseURL: URL
    private let model: String
    private let directAPIKey: String?

    public init(
        credentialStore: CredentialStore,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        baseURL: URL,
        model: String
    ) {
        self.credentialStore = credentialStore
        self.httpClient = httpClient
        self.directAPIKey = nil
        self.baseURL = baseURL
        self.model = model
    }

    public init(
        credentialStore: CredentialStore,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        endpoint: String,
        apiKey: String,
        model: String
    ) {
        self.credentialStore = credentialStore
        self.httpClient = httpClient
        self.directAPIKey = apiKey
        self.baseURL = URL(string: endpoint.hasSuffix("/") ? String(endpoint.dropLast()) : endpoint)!
        self.model = model
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        let chatURL = baseURL.appendingPathComponent("chat/completions")
        let hasImages = request.attachmentContext.contains { $0.kind == .image }

        var lastRawText = ""
        var messages = buildMessages(from: request)
        var traceStages: [PromptPipelineStageTrace] = [
            PromptPipelineStageTrace(
                name: .buildPrompt,
                status: .passed,
                inputCharacters: request.userPrompt.count,
                detail: "messages=\(messages.count), images=\(request.attachmentContext.filter { $0.kind == .image }.count)"
            )
        ]

        for attempt in 0..<5 {
            let traceAttempt = attempt + 1
            let payload = OAICompatRequest(
                model: model,
                messages: messages,
                temperature: 0.2,
                maxTokens: 1024
            )
            kairoOmlxLog("[OMLX] url=\(chatURL.absoluteString) model=\(model) messagesCount=\(payload.messages.count) attempt=\(attempt)")
            for (i, m) in payload.messages.enumerated() {
                let preview = String(m.text.replacingOccurrences(of: "\n", with: " ").prefix(140))
                kairoOmlxLog("[OMLX]   msg[\(i)] role=\(m.role) len=\(m.text.count) preview=\(preview)")
            }

            let (decoded, rawText, elapsed, statusCode) = try await postWithTransientRetry(
                payload: payload,
                url: chatURL
            )
            lastRawText = rawText
            traceStages.append(PromptPipelineStageTrace(
                name: .requestModel,
                status: .passed,
                attempt: traceAttempt,
                inputCharacters: payload.messages.map(\.text.count).reduce(0, +),
                outputCharacters: rawText.count,
                detail: "http=\(statusCode), \(String(format: "%.0f", elapsed))ms"
            ))
            kairoOmlxLog("[OMLX] response status=\(statusCode) elapsed=\(String(format: "%.0f", elapsed))ms tokens=\(decoded.usage?.totalTokens ?? 0) messageLen=\(rawText.count)")
            kairoOmlxLog("[OMLX] message=\(String(rawText.prefix(200)))")

            let (displayMessage, rawJSON, infoPageDraft) = Self.parseStructuredResponse(rawText)
            traceStages.append(PromptPipelineStageTrace(
                name: .parseStructuredOutput,
                status: infoPageDraft != nil || !hasImages ? .passed : .failed,
                attempt: traceAttempt,
                outputCharacters: rawJSON?.count ?? rawText.count,
                detail: infoPageDraft == nil && hasImages ? "missing InfoPage JSON" : "message=\(displayMessage.count)"
            ))
            let metrics = AIInferenceMetrics(
                stage: .complete,
                promptTokens: decoded.usage?.promptTokens ?? decoded.usage?.totalTokens,
                generatedTokens: decoded.usage?.completionTokens
            )

            if infoPageDraft != nil || !hasImages {
                let trace = PromptPipelineTrace(
                    providerID: "openai-compatible",
                    status: infoPageDraft != nil ? .validated : .needsReview,
                    stages: traceStages,
                    validationIssues: infoPageDraft == nil && hasImages ? ["missing InfoPage JSON"] : []
                )
                return AICompletionResponse(
                    message: displayMessage,
                    proposedActions: [],
                    inferenceMetrics: metrics,
                    rawModelResponse: rawJSON,
                    infoPageDraft: infoPageDraft,
                    promptPipelineTrace: trace
                )
            }

            kairoOmlxLog("[OMLX] parse failed, retrying... attempt=\(attempt)")
            let repairPrompt = """
            Your last response was not valid. You must output ONLY the JSON object matching this schema exactly, with ALL required fields. No markdown, no prose, no extra text:

            {"createInfoPage":true,"title":"...","templateID":"generalNote","category":"generalNote","assetDescription":"...","ocrSummary":"...","keywords":[],"candidateCategories":[{"folderName":"...","templateID":"generalNote","category":"generalNote","confidence":0.9,"reason":"..."}],"selectedSubcategoryIDs":[],"suggestedSubcategoryName":null,"summary":"...","facts":[{"label":"...","value":"...","sourceAssetID":null}],"timeline":[],"reminderDrafts":[],"folderName":"...","confidence":0.9,"missingInfo":[],"sourceAssetIDs":[]}

            Your last output was:
            \(String(rawText.prefix(300)))
            """
            traceStages.append(PromptPipelineStageTrace(
                name: .repairPrompt,
                status: .repaired,
                attempt: traceAttempt,
                inputCharacters: repairPrompt.count,
                detail: "retry structured JSON"
            ))
            messages.append(OAICompatMessage(role: "user", text: repairPrompt))
        }

        let (displayMessage, rawJSON, infoPageDraft) = Self.parseStructuredResponse(lastRawText)
        let finalIssue = infoPageDraft == nil && hasImages ? ["missing InfoPage JSON after repair"] : []
        return AICompletionResponse(
            message: displayMessage,
            proposedActions: [],
            rawModelResponse: rawJSON,
            infoPageDraft: infoPageDraft,
            promptPipelineTrace: PromptPipelineTrace(
                providerID: "openai-compatible",
                status: infoPageDraft == nil && hasImages ? .failed : .needsReview,
                stages: traceStages,
                validationIssues: finalIssue
            )
        )
    }

    /// Retries the HTTP call up to 4 times (initial + 3 retries) when the server returns a 5xx,
    /// an unexpected body shape, or a transient transport error. Auth and missing-credential
    /// failures are not retried because they would just repeat the same failure.
    private func postWithTransientRetry(
        payload: OAICompatRequest,
        url: URL
    ) async throws -> (decoded: OAICompatResponse, rawText: String, elapsedMs: Double, statusCode: Int) {
        let maxAttempts = 4
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                let result = try await postOnce(payload: payload, url: url)
                if attempt > 0 {
                    kairoOmlxLog("[OMLX] transient retry succeeded after attempt=\(attempt)")
                }
                return result
            } catch let error as AIProviderError {
                lastError = error
                if case .missingCredential = error { throw error }
                if !Self.isRetryable(error) { throw error }
                kairoOmlxLog("[OMLX] transient retry attempt=\(attempt + 1)/\(maxAttempts) error=\(error)")
                try? await Task.sleep(nanoseconds: UInt64(Self.backoffMilliseconds(forAttempt: attempt)) * 1_000_000)
            } catch {
                lastError = error
                kairoOmlxLog("[OMLX] transient retry attempt=\(attempt + 1)/\(maxAttempts) error=\(error.localizedDescription)")
                try? await Task.sleep(nanoseconds: UInt64(Self.backoffMilliseconds(forAttempt: attempt)) * 1_000_000)
            }
        }
        throw lastError ?? AIProviderError.requestFailed("OMLX call failed after \(maxAttempts) attempts")
    }

    private func postOnce(
        payload: OAICompatRequest,
        url: URL
    ) async throws -> (decoded: OAICompatResponse, rawText: String, elapsedMs: Double, statusCode: Int) {
        let data = try JSONEncoder().encode(payload)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(try await apiKey())", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data
        urlRequest.timeoutInterval = 120

        let startTime = CFAbsoluteTimeGetCurrent()
        let (responseData, response) = try await httpClient.data(for: urlRequest)
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        try validate(response, data: responseData)

        do {
            let decoded = try JSONDecoder().decode(OAICompatResponse.self, from: responseData)
            let rawText = decoded.choices.first?.message.text ?? ""
            return (decoded, rawText, elapsed, response.statusCode)
        } catch {
            let bodyPreview = String(data: responseData, encoding: .utf8).map { String($0.prefix(800)) } ?? "<non-utf8 body>"
            kairoOmlxLog("[OMLX] decode failed status=\(response.statusCode) elapsed=\(String(format: "%.0f", elapsed))ms error=\(error.localizedDescription) body=\(bodyPreview)")
            if let envelope = try? JSONDecoder().decode(OAICompatErrorEnvelope.self, from: responseData),
               let message = envelope.error?.message, !message.isEmpty {
                throw AIProviderError.requestFailed(message)
            }
            throw AIProviderError.requestFailed("OMLX response not in OpenAI chat-completions shape: \(bodyPreview)")
        }
    }

    private static func isRetryable(_ error: AIProviderError) -> Bool {
        switch error {
        case .missingCredential, .unsupported:
            return false
        case .requestFailed(let message):
            // 4xx (other than 408 / 429) is a client problem — retrying repeats it. Retry 5xx and shape errors.
            if message.hasPrefix("HTTP 4") {
                return message.hasPrefix("HTTP 408") || message.hasPrefix("HTTP 429")
            }
            return true
        case .localInferenceUnavailable:
            return false
        }
    }

    private static func backoffMilliseconds(forAttempt attempt: Int) -> Int {
        // 300ms, 700ms, 1500ms — short enough to be unobtrusive on a chat turn.
        let base = [300, 700, 1500]
        return base[min(attempt, base.count - 1)]
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        let apiKey = try await apiKey()
        let embedURL = baseURL.appendingPathComponent("embeddings")
        let payload: [String: Any] = ["model": model, "input": request.input]
        let data = try JSONSerialization.data(withJSONObject: payload)
        var urlRequest = URLRequest(url: embedURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data
        urlRequest.timeoutInterval = 30

        let (responseData, response) = try await httpClient.data(for: urlRequest)
        try validate(response, data: responseData)

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first,
              let embedding = first["embedding"] as? [Double]
        else {
            throw AIProviderError.requestFailed("Missing embedding vector in response")
        }
        return AIEmbeddingResponse(vector: embedding)
    }

    public static func defaultOmlxProvider(credentialStore: CredentialStore) -> OpenAICompatibleProvider {
        OpenAICompatibleProvider(
            credentialStore: credentialStore,
            baseURL: URL(string: "http://localhost:8000/v1")!,
            model: "gemma-4-e2b-it-4bit"
        )
    }

    private func apiKey() async throws -> String {
        if let directAPIKey { return directAPIKey }
        guard let apiKey = try await credentialStore.readSecret(for: CredentialKey.openAICompatibleAPIKey), !apiKey.isEmpty else {
            throw AIProviderError.missingCredential
        }
        return apiKey
    }

    private func buildMessages(from request: AICompletionRequest) -> [OAICompatMessage] {
        var messages: [OAICompatMessage] = [
            OAICompatMessage(role: "system", text: request.systemPrompt),
            OAICompatMessage(role: "system", text: AIRequestPromptComposer.sessionContext(from: request))
        ]

        for turn in request.conversationHistory {
            switch turn.role {
            case .user:
                messages.append(OAICompatMessage(role: "user", text: turn.text))
            case .assistant:
                messages.append(OAICompatMessage(role: "assistant", text: turn.text))
            }
        }

        let currentUserText = AIRequestPromptComposer.currentUserText(from: request)
        let imageAttachments = request.attachmentContext.filter { $0.kind == .image }
        let maxImages = 6
        if !imageAttachments.isEmpty {
            var parts: [OAICompatContentPart] = []
            for attachment in imageAttachments.prefix(maxImages) {
                if let imageURL = attachment.fileURL, let dataURL = base64DataURL(from: imageURL) {
                    parts.append(OAICompatContentPart(imageURL: dataURL))
                }
            }
            if !currentUserText.isEmpty {
                parts.append(OAICompatContentPart(text: currentUserText))
            }
            if !parts.isEmpty {
                messages.append(OAICompatMessage(role: "user", parts: parts))
            }
        } else {
            messages.append(OAICompatMessage(role: "user", text: currentUserText))
        }

        return messages
    }

    private func base64DataURL(from fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return nil }
        let maxDimension: CGFloat = 1024
        let mimeType: String
        let encodedData: Data
        #if canImport(UIKit)
        if let image = UIImage(data: data) {
            let size = image.size
            if size.width > maxDimension || size.height > maxDimension {
                let scale = min(maxDimension / size.width, maxDimension / size.height)
                let newSize = CGSize(width: size.width * scale, height: size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let resized = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                if let jpeg = resized?.jpegData(compressionQuality: 0.8) {
                    encodedData = jpeg
                    mimeType = "image/jpeg"
                } else {
                    encodedData = data
                    mimeType = mimeTypeForURL(fileURL)
                }
            } else {
                encodedData = data
                mimeType = mimeTypeForURL(fileURL)
            }
        } else {
            encodedData = data
            mimeType = mimeTypeForURL(fileURL)
        }
        #else
        encodedData = data
        mimeType = mimeTypeForURL(fileURL)
        #endif
        return "data:\(mimeType);base64,\(encodedData.base64EncodedString())"
    }

    private func mimeTypeForURL(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png":  return "image/png"
        case "gif":  return "image/gif"
        case "webp": return "image/webp"
        default:     return "image/jpeg"
        }
    }

    private static func parseStructuredResponse(_ raw: String) -> (displayMessage: String, rawJSON: String?, infoPageDraft: InfoPageDraft?) {
        guard let jsonString = extractJSONObject(from: raw),
              let data = jsonString.data(using: .utf8)
        else {
            return (raw.trimmingCharacters(in: .whitespacesAndNewlines), nil, nil)
        }

        let pretty = prettyPrintedJSON(jsonString) ?? jsonString

        guard var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              dict["createInfoPage"] as? Bool == true
        else {
            return (raw.trimmingCharacters(in: .whitespacesAndNewlines), pretty.isEmpty ? nil : pretty, nil)
        }

        dict["confidence"] = dict["confidence"] ?? 0.0
        dict["missingInfo"] = dict["missingInfo"] ?? [String]()
        dict["sourceAssetIDs"] = dict["sourceAssetIDs"] ?? [String]()

        let sanitized = sanitizeDraftJSON(in: dict)
        guard let sanitizedData = try? JSONSerialization.data(withJSONObject: sanitized),
              let draft = try? JSONDecoder().decode(InfoPageDraft.self, from: sanitizedData)
        else {
            return (raw.trimmingCharacters(in: .whitespacesAndNewlines), pretty, nil)
        }

        let message = draft.assetDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? draft.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return (message, pretty, draft)
    }

    private static func sanitizeDraftJSON(in dict: [String: Any]) -> [String: Any] {
        var result = sanitizeSourceAssetIDs(in: dict)

        let validCategories: Set<String> = ["travel", "order", "warranty", "project", "event", "medical", "finance", "identityDocument", "homeDevice", "subscription", "recipeOrInstruction", "generalNote"]
        let categoryAliases: [String: String] = [
            "general": "generalNote", "note": "generalNote", "generalnote": "generalNote",
            "traveling": "travel", "trip": "travel", "旅行": "travel",
            "order": "order", "购物": "order",
            "receipt": "order", "invoice": "finance",
            "document": "identityDocument", "id": "identityDocument",
            "home": "homeDevice", "device": "homeDevice",
            "food": "recipeOrInstruction", "recipe": "recipeOrInstruction",
            "medical": "medical", "health": "medical",
            "finance": "finance", "money": "finance",
            "event": "event", "calendar": "event",
            "project": "project",
            "warranty": "warranty",
            "subscription": "subscription",
            "asset": "generalNote", "photo": "generalNote", "image": "generalNote", "picture": "generalNote"
        ]

        func sanitizeCategory(_ raw: String?) -> String? {
            guard let raw, !raw.isEmpty else { return nil }
            let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if validCategories.contains(lower) { return lower }
            if let mapped = categoryAliases[lower] { return mapped }
            return "generalNote"
        }

        if let category = result["category"] as? String {
            result["category"] = sanitizeCategory(category)
        }
        if let templateID = result["templateID"] as? String {
            result["templateID"] = sanitizeCategory(templateID)
        }
        if var candidates = result["candidateCategories"] as? [[String: Any]] {
            for i in candidates.indices {
                if let cat = candidates[i]["category"] as? String {
                    candidates[i]["category"] = sanitizeCategory(cat)
                }
                if let tid = candidates[i]["templateID"] as? String {
                    candidates[i]["templateID"] = sanitizeCategory(tid)
                }
                if let fn = candidates[i]["folderName"] as? String, !fn.isEmpty {
                    candidates[i]["folderName"] = fn
                }
            }
            result["candidateCategories"] = candidates
        }

        return result
    }

    private static func sanitizeSourceAssetIDs(in dict: [String: Any]) -> [String: Any] {
        var result = dict
        if var facts = result["facts"] as? [[String: Any]] {
            for i in facts.indices {
                if let id = facts[i]["sourceAssetID"] as? String, UUID(uuidString: id) == nil {
                    facts[i].removeValue(forKey: "sourceAssetID")
                }
            }
            result["facts"] = facts
        }
        if var timeline = result["timeline"] as? [[String: Any]] {
            for i in timeline.indices {
                if let id = timeline[i]["sourceAssetID"] as? String, UUID(uuidString: id) == nil {
                    timeline[i].removeValue(forKey: "sourceAssetID")
                }
            }
            result["timeline"] = timeline
        }
        if let sa = result["sourceAssetIDs"] as? [Any] {
            result["sourceAssetIDs"] = sa.compactMap { item -> UUID? in
                if let uuidStr = item as? String, let uuid = UUID(uuidString: uuidStr) {
                    return uuid
                }
                return nil
            }
        }
        return result
    }

    private static func extractJSONObject(from raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"),
              start <= end
        else { return nil }
        return String(raw[start...end])
    }

    private static func prettyPrintedJSON(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: pretty, encoding: .utf8)
        else { return nil }
        return result
    }

    private func validate(_ response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            let prefix = String(body.prefix(500))
            throw AIProviderError.requestFailed("HTTP \(response.statusCode): \(prefix)")
        }
    }
}

private struct OAICompatRequest: Codable {
    var model: String
    var messages: [OAICompatMessage]
    var temperature: Double
    var maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct OAICompatMessage: Codable {
    var role: String
    var content: OAICompatMessageContent?

    init(role: String, text: String) {
        self.role = role
        self.content = .text(text)
    }

    init(role: String, parts: [OAICompatContentPart]) {
        self.role = role
        self.content = .parts(parts)
    }

    var text: String {
        switch content {
        case .text(let s): return s
        case .parts(let parts): return parts.compactMap(\.text).joined(separator: " ")
        case nil: return ""
        }
    }
}

private enum OAICompatMessageContent: Codable {
    case text(String)
    case parts([OAICompatContentPart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s): try container.encode(s)
        case .parts(let p): try container.encode(p)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .text("")
            return
        }
        if let str = try? container.decode(String.self) {
            self = .text(str)
            return
        }
        if let parts = try? container.decode([OAICompatContentPart].self) {
            self = .parts(parts)
            return
        }
        // Some servers wrap message content into an object like {"text": "..."} or {"value": "..."}.
        // Tolerate that instead of failing the whole response decode.
        if let dict = try? container.decode([String: String].self),
           let value = dict["text"] ?? dict["value"] ?? dict["content"] {
            self = .text(value)
            return
        }
        self = .text("")
    }
}

private struct OAICompatContentPart: Codable {
    var type: String
    var text: String?
    var image_url: OAICompatImageURL?

    init(text: String) {
        self.type = "text"
        self.text = text
        self.image_url = nil
    }

    init(imageURL: String) {
        self.type = "image_url"
        self.text = nil
        self.image_url = OAICompatImageURL(url: imageURL)
    }
}

private struct OAICompatImageURL: Codable {
    var url: String
}

private struct OAICompatResponse: Codable {
    var choices: [OAICompatChoice]
    var usage: OAICompatUsage?
}

private struct OAICompatErrorEnvelope: Codable {
    var error: OAICompatErrorBody?
}

private struct OAICompatErrorBody: Codable {
    var message: String?
    var type: String?
    var code: String?
}

private struct OAICompatUsage: Codable {
    var totalTokens: Int?
    var promptTokens: Int?
    var completionTokens: Int?

    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }
}

private struct OAICompatChoice: Codable {
    var message: OAICompatMessage
    var index: Int?
    var finishReason: String?

    enum CodingKeys: String, CodingKey {
        case message
        case index
        case finishReason = "finish_reason"
    }
}
