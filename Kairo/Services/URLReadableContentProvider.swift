import Foundation

public struct URLReadableContent: Equatable, Sendable {
    public var title: String?
    public var description: String?
    public var textSnippet: String?

    public init(title: String? = nil, description: String? = nil, textSnippet: String? = nil) {
        self.title = title
        self.description = description
        self.textSnippet = textSnippet
    }
}

public protocol URLReadableContentProviding: Sendable {
    func readableContent(for url: URL) async -> URLReadableContent?
}

public struct EmptyURLReadableContentProvider: URLReadableContentProviding {
    public init() {}

    public func readableContent(for url: URL) async -> URLReadableContent? {
        _ = url
        return nil
    }
}

public struct URLReadableContentProviderFactory {
    public static func live() -> any URLReadableContentProviding {
        URLSessionReadableContentProvider()
    }
}

public struct URLSessionReadableContentProvider: URLReadableContentProviding {
    private let maximumHTMLBytes: Int
    private let timeout: TimeInterval

    public init(maximumHTMLBytes: Int = 256 * 1024, timeout: TimeInterval = 4) {
        self.maximumHTMLBytes = maximumHTMLBytes
        self.timeout = timeout
    }

    public func readableContent(for url: URL) async -> URLReadableContent? {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
               !contentType.contains("html") && !contentType.contains("text/plain") {
                return nil
            }
            let boundedData = data.prefix(maximumHTMLBytes)
            guard let html = String(data: Data(boundedData), encoding: .utf8)
                ?? String(data: Data(boundedData), encoding: .isoLatin1) else {
                return nil
            }
            return HTMLReadableContentExtractor().extract(from: html)
        } catch {
            return nil
        }
    }
}

public struct HTMLReadableContentExtractor: Sendable {
    private let maximumSnippetCharacters: Int

    public init(maximumSnippetCharacters: Int = 1_200) {
        self.maximumSnippetCharacters = maximumSnippetCharacters
    }

    public func extract(from html: String) -> URLReadableContent? {
        let title = firstMatch(
            in: html,
            pattern: #"<title[^>]*>(.*?)</title>"#
        )
        let description = metaContent(in: html, names: ["description", "og:description", "twitter:description"])
        let textSnippet = readableText(from: html)
        guard title != nil || description != nil || textSnippet != nil else { return nil }
        return URLReadableContent(title: title, description: description, textSnippet: textSnippet)
    }

    private func metaContent(in html: String, names: [String]) -> String? {
        for name in names {
            let escapedName = NSRegularExpression.escapedPattern(for: name)
            let patterns = [
                #"<meta[^>]+(?:name|property)=["']"# + escapedName + #"["'][^>]+content=["']([^"']+)["'][^>]*>"#,
                #"<meta[^>]+content=["']([^"']+)["'][^>]+(?:name|property)=["']"# + escapedName + #"["'][^>]*>"#
            ]
            for pattern in patterns {
                if let match = firstMatch(in: html, pattern: pattern) {
                    return match
                }
            }
        }
        return nil
    }

    private func readableText(from html: String) -> String? {
        let withoutScripts = replacingMatches(
            in: html,
            pattern: #"<(script|style|noscript)[^>]*>.*?</\1>"#,
            with: " "
        )
        let textBlocks = blockMatches(in: withoutScripts, tag: "p") +
            blockMatches(in: withoutScripts, tag: "li") +
            blockMatches(in: withoutScripts, tag: "h1") +
            blockMatches(in: withoutScripts, tag: "h2")
        let joined = textBlocks
            .map(cleanText)
            .filter { $0.count > 24 }
            .joined(separator: " ")
        let fallback = cleanText(replacingMatches(in: withoutScripts, pattern: #"<[^>]+>"#, with: " "))
        let selected = joined.isEmpty ? fallback : joined
        guard !selected.isEmpty else { return nil }
        return String(selected.prefix(maximumSnippetCharacters))
    }

    private func blockMatches(in html: String, tag: String) -> [String] {
        let pattern = #"<"# + tag + #"[^>]*>(.*?)</"# + tag + #">"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { result in
            guard result.numberOfRanges > 1, let matchRange = Range(result.range(at: 1), in: html) else {
                return nil
            }
            return String(html[matchRange])
        }
    }

    private func firstMatch(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let result = regex.firstMatch(in: html, range: range),
              result.numberOfRanges > 1,
              let matchRange = Range(result.range(at: 1), in: html) else {
            return nil
        }
        return cleanText(String(html[matchRange]))
    }

    private func replacingMatches(in text: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    private func cleanText(_ text: String) -> String {
        let withoutTags = replacingMatches(in: text, pattern: #"<[^>]+>"#, with: " ")
        let decoded = withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        return decoded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
