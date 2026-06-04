import Foundation

public struct MemoryPromptContextBuilder: Sendable {
    public init() {}

    public func build(from memories: [MemoryRecord]) -> String {
        let lines = memories.map(Self.line(for:))
        return lines.isEmpty ? "None" : lines.joined(separator: "\n")
    }

    private static func line(for memory: MemoryRecord) -> String {
        let summary = compact(memory.summary)
        let content = compact(memory.content)
        let detail = content.isEmpty || normalize(content) == normalize(summary)
            ? ""
            : " Details: \(String(content.prefix(360)))"
        return "- [\(memory.source.rawValue)] \(memory.title): \(summary)\(detail)"
    }

    private static func compact(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalize(_ value: String) -> String {
        compact(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
