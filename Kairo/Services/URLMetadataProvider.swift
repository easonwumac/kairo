import Foundation

#if canImport(LinkPresentation)
import LinkPresentation
#endif

public struct URLReadingMetadata: Equatable, Sendable {
    public var title: String?
    public var siteName: String?
    public var resolvedURL: URL?

    public init(title: String? = nil, siteName: String? = nil, resolvedURL: URL? = nil) {
        self.title = title
        self.siteName = siteName
        self.resolvedURL = resolvedURL
    }
}

public protocol URLMetadataProviding: Sendable {
    func metadata(for url: URL) async -> URLReadingMetadata?
}

public struct EmptyURLMetadataProvider: URLMetadataProviding {
    public init() {}

    public func metadata(for url: URL) async -> URLReadingMetadata? {
        _ = url
        return nil
    }
}

public enum URLMetadataProviderFactory {
    public static func live() -> any URLMetadataProviding {
        #if canImport(LinkPresentation)
        LinkPresentationURLMetadataProvider()
        #else
        EmptyURLMetadataProvider()
        #endif
    }
}

#if canImport(LinkPresentation)
public struct LinkPresentationURLMetadataProvider: URLMetadataProviding {
    public init() {}

    public func metadata(for url: URL) async -> URLReadingMetadata? {
        await withCheckedContinuation { continuation in
            let provider = LPMetadataProvider()
            provider.startFetchingMetadata(for: url) { metadata, _ in
                guard let metadata else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: URLReadingMetadata(
                    title: metadata.title,
                    siteName: Self.siteName(from: metadata.originalURL ?? metadata.url ?? url),
                    resolvedURL: metadata.url ?? metadata.originalURL
                ))
            }
        }
    }

    private static func siteName(from url: URL) -> String? {
        url.host(percentEncoded: false)?
            .lowercased()
            .replacingOccurrences(of: #"^www\."#, with: "", options: .regularExpression)
    }
}
#endif
