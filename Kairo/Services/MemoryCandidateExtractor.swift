import Foundation

public struct MemoryCandidateExtractor: Sendable {
    public init() {}

    public func proposedSaveMemoryAction(
        from userMessage: String,
        memoryContext: [MemoryRecord]
    ) -> AgentAction? {
        guard let memoryText = Self.extractMemoryText(from: userMessage),
              !Self.isDuplicate(memoryText, in: memoryContext)
        else {
            return nil
        }

        return AgentAction(
            kind: .saveMemory,
            title: KairoL10n.string("chat.memory.proposal.title"),
            rationale: KairoL10n.string("chat.memory.proposal.rationale"),
            payload: .text(memoryText),
            riskTier: .tier2LowRiskWrite
        )
    }

    private static func extractMemoryText(from message: String) -> String? {
        let singleLine = message
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard singleLine.count >= 12 else { return nil }

        if let explicit = extractAfterAnyPrefix(in: singleLine, prefixes: explicitMemoryPrefixes) {
            return boundedMemoryText(explicit)
        }

        if containsAny(singleLine, markers: preferenceMarkers) || containsAny(singleLine, markers: identityMarkers) {
            return boundedMemoryText(singleLine)
        }

        return nil
    }

    private static func extractAfterAnyPrefix(in text: String, prefixes: [String]) -> String? {
        let normalizedText = normalize(text)
        for prefix in prefixes {
            let normalizedPrefix = normalize(prefix)
            if normalizedText.hasPrefix(normalizedPrefix) {
                let start = text.index(text.startIndex, offsetBy: min(prefix.count, text.count))
                let suffix = text[start...]
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
                let refined = removingLeadingMemoryConnector(from: suffix)
                guard refined.count >= 8 else { return nil }
                return refined
            }
        }
        return nil
    }

    private static func boundedMemoryText(_ text: String) -> String? {
        let cleaned = text
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        guard cleaned.count >= 8 else { return nil }
        return String(cleaned.prefix(240))
    }

    private static func removingLeadingMemoryConnector(from text: String) -> String {
        let connectors = ["that ", "這件事：", "這件事:"]
        let normalizedText = normalize(text)
        for connector in connectors where normalizedText.hasPrefix(normalize(connector)) {
            let start = text.index(text.startIndex, offsetBy: min(connector.count, text.count))
            return text[start...].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func isDuplicate(_ memoryText: String, in context: [MemoryRecord]) -> Bool {
        let normalizedCandidate = normalize(memoryText)
        return context.contains { record in
            let existing = normalize([record.title, record.summary, record.content].joined(separator: " "))
            return existing.contains(normalizedCandidate) || normalizedCandidate.contains(normalize(record.summary))
        }
    }

    private static func containsAny(_ text: String, markers: [String]) -> Bool {
        let normalizedText = normalize(text)
        return markers.contains { normalizedText.contains(normalize($0)) }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static let explicitMemoryPrefixes = [
        "remember that",
        "remember:",
        "please remember",
        "keep in mind that",
        "請記住",
        "幫我記住",
        "記住"
    ]

    private static let preferenceMarkers = [
        "i prefer",
        "i usually",
        "i like",
        "my preference is",
        "我偏好",
        "我通常",
        "我喜歡"
    ]

    private static let identityMarkers = [
        "my name is",
        "my email is",
        "my phone is",
        "my timezone is",
        "我的名字是",
        "我的 email 是",
        "我的電話是",
        "我的時區是"
    ]
}
