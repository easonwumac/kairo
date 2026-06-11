import Foundation

public protocol AgentWikiContextProviding: Sendable {
    func context(
        for message: String,
        privacyMode: ChatPrivacyMode
    ) async throws -> [KairoWikiSearchResult]
}

public actor DefaultAgentWikiContextProvider: AgentWikiContextProviding {
    private let wikiSearchService: any KairoWikiSearchProviding
    private let limit: Int

    public init(
        wikiSearchService: any KairoWikiSearchProviding,
        limit: Int = 6
    ) {
        self.wikiSearchService = wikiSearchService
        self.limit = limit
    }

    public func context(
        for message: String,
        privacyMode: ChatPrivacyMode
    ) async throws -> [KairoWikiSearchResult] {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard privacyMode != .privateChat, !trimmed.isEmpty else {
            return []
        }
        return try await wikiSearchService.search(query: trimmed, limit: limit)
    }
}

public struct EmptyAgentWikiContextProvider: AgentWikiContextProviding {
    public init() {}

    public func context(
        for message: String,
        privacyMode: ChatPrivacyMode
    ) async throws -> [KairoWikiSearchResult] {
        _ = message
        _ = privacyMode
        return []
    }
}
