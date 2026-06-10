import Foundation

public enum KairoURLScheme: String, Sendable {
    case kairo = "kairo"
}

public enum KairoURLRoute: Equatable, Sendable {
    case infoPage(id: UUID)
    case memoryRecord(id: UUID)
    case knowledgeAsset(id: UUID)
    case search(query: String)
    case chatThread(id: UUID)

    public var deepLink: URL? {
        switch self {
        case .infoPage(let id):
            return URL(string: "\(KairoURLScheme.kairo.rawValue)://info-page/\(id.uuidString)")
        case .memoryRecord(let id):
            return URL(string: "\(KairoURLScheme.kairo.rawValue)://memory/\(id.uuidString)")
        case .knowledgeAsset(let id):
            return URL(string: "\(KairoURLScheme.kairo.rawValue)://asset/\(id.uuidString)")
        case .search(let query):
            guard let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return URL(string: "\(KairoURLScheme.kairo.rawValue)://search?q=\(escaped)")
        case .chatThread(let id):
            return URL(string: "\(KairoURLScheme.kairo.rawValue)://chat/\(id.uuidString)")
        }
    }
}

public struct KairoURLRouter: Sendable {
    public let scheme: KairoURLScheme

    public init(scheme: KairoURLScheme = .kairo) {
        self.scheme = scheme
    }

    public func parse(_ url: URL) -> KairoURLRoute? {
        guard url.scheme?.lowercased() == scheme.rawValue else { return nil }
        let host = url.host?.lowercased() ?? ""
        let segments = url.pathComponents.filter { $0 != "/" }
        let firstSegment = segments.first
        let queryItem = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "q" })?.value
        guard let id = firstSegment, let uuid = UUID(uuidString: id) else {
            if host == "search", let queryItem, !queryItem.isEmpty {
                return .search(query: queryItem)
            }
            return nil
        }
        switch host {
        case "info-page":
            return .infoPage(id: uuid)
        case "memory":
            return .memoryRecord(id: uuid)
        case "asset":
            return .knowledgeAsset(id: uuid)
        case "chat":
            return .chatThread(id: uuid)
        default:
            return nil
        }
    }
}
