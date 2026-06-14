import Foundation

public struct URLReadingContext: Equatable, Sendable {
    public var url: URL
    public var siteName: String
    public var titleCandidate: String?
    public var metadataTitle: String?
    public var metadataResolvedURL: URL?
    public var readableTitle: String?
    public var readableDescription: String?
    public var readableTextSnippet: String?
    public var topics: [String]

    public init(
        url: URL,
        siteName: String,
        titleCandidate: String? = nil,
        metadataTitle: String? = nil,
        metadataResolvedURL: URL? = nil,
        readableTitle: String? = nil,
        readableDescription: String? = nil,
        readableTextSnippet: String? = nil,
        topics: [String] = []
    ) {
        self.url = url
        self.siteName = siteName
        self.titleCandidate = titleCandidate
        self.metadataTitle = metadataTitle
        self.metadataResolvedURL = metadataResolvedURL
        self.readableTitle = readableTitle
        self.readableDescription = readableDescription
        self.readableTextSnippet = readableTextSnippet
        self.topics = topics
    }

    public var promptLine: String {
        var parts = [
            "URL: \(url.absoluteString)",
            "site: \(siteName)"
        ]
        if let metadataTitle, !metadataTitle.isEmpty {
            parts.append("metadataTitle: \(metadataTitle)")
        }
        if let metadataResolvedURL, metadataResolvedURL != url {
            parts.append("resolvedURL: \(metadataResolvedURL.absoluteString)")
        }
        if let readableTitle, !readableTitle.isEmpty, readableTitle != metadataTitle {
            parts.append("pageTitle: \(readableTitle)")
        }
        if let readableDescription, !readableDescription.isEmpty {
            parts.append("pageDescription: \(readableDescription)")
        }
        if let readableTextSnippet, !readableTextSnippet.isEmpty {
            parts.append("pageText: \(readableTextSnippet)")
        }
        if let titleCandidate, !titleCandidate.isEmpty {
            parts.append("titleCandidate: \(titleCandidate)")
        }
        if !topics.isEmpty {
            parts.append("topics: \(topics.joined(separator: ", "))")
        }
        return parts.joined(separator: "\n")
    }
}

public struct URLReadingContextBuilder: Sendable {
    private static let ignoredQueryKeys: Set<String> = [
        "fbclid",
        "gclid",
        "mc_cid",
        "mc_eid",
        "ref",
        "source",
        "utm_campaign",
        "utm_content",
        "utm_medium",
        "utm_source",
        "utm_term"
    ]

    public init() {}

    public func contexts(
        from urls: [URL],
        metadata: [URL: URLReadingMetadata] = [:],
        readableContent: [URL: URLReadableContent] = [:],
        limit: Int = 4
    ) -> [URLReadingContext] {
        urls
            .prefix(limit)
            .map { context(from: $0, metadata: metadata[$0], readableContent: readableContent[$0]) }
    }

    public func promptBlock(
        from urls: [URL],
        metadata: [URL: URLReadingMetadata] = [:],
        readableContent: [URL: URLReadableContent] = [:],
        limit: Int = 4
    ) -> String {
        contexts(from: urls, metadata: metadata, readableContent: readableContent, limit: limit)
            .map(\.promptLine)
            .joined(separator: "\n---\n")
    }

    public func context(
        from url: URL,
        metadata: URLReadingMetadata? = nil,
        readableContent: URLReadableContent? = nil
    ) -> URLReadingContext {
        let siteName = normalized(metadata?.siteName) ?? normalizedHost(for: url)
        let pathTokens = tokens(fromPath: url.path)
        let queryTokens = tokens(fromQuery: url)
        let allTopics = deduplicated(pathTokens + queryTokens)
        return URLReadingContext(
            url: url,
            siteName: siteName,
            titleCandidate: titleCandidate(from: pathTokens),
            metadataTitle: normalized(metadata?.title),
            metadataResolvedURL: metadata?.resolvedURL,
            readableTitle: normalized(readableContent?.title),
            readableDescription: normalized(readableContent?.description),
            readableTextSnippet: normalized(readableContent?.textSnippet),
            topics: Array(allTopics.prefix(8))
        )
    }

    private func normalizedHost(for url: URL) -> String {
        let host = url.host(percentEncoded: false) ?? url.host ?? url.absoluteString
        return host
            .lowercased()
            .replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
    }

    private func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func tokens(fromPath path: String) -> [String] {
        path
            .split(separator: "/")
            .flatMap { segment in
                normalizedTokens(from: String(segment).removingPercentEncoding ?? String(segment))
            }
    }

    private func tokens(fromQuery url: URL) -> [String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return []
        }
        return queryItems.flatMap { item -> [String] in
            let key = item.name.lowercased()
            guard !Self.ignoredQueryKeys.contains(key), let value = item.value else { return [] }
            return normalizedTokens(from: value.removingPercentEncoding ?? value)
        }
    }

    private func normalizedTokens(from raw: String) -> [String] {
        raw
            .replacingOccurrences(of: #"\.[A-Za-z0-9]{1,8}$"#, with: "", options: .regularExpression)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { token in
                token.count > 2 && token.rangeOfCharacter(from: .decimalDigits) == nil
            }
    }

    private func titleCandidate(from tokens: [String]) -> String? {
        let meaningful = tokens.suffix(8)
        guard !meaningful.isEmpty else { return nil }
        return meaningful
            .map { token in
                token.prefix(1).uppercased() + token.dropFirst()
            }
            .joined(separator: " ")
    }

    private func deduplicated(_ tokens: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for token in tokens where !seen.contains(token) {
            seen.insert(token)
            result.append(token)
        }
        return result
    }
}
