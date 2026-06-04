import Foundation

public struct OAuthConnectorCallbackPreview: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var providerKey: String
    public var integrationKey: String
    public var state: String?
    public var authorizationCodeLength: Int
    public var receivedAt: Date
    public var requiresBackendTokenExchange: Bool

    public init(
        id: String = UUID().uuidString,
        providerKey: String,
        integrationKey: String,
        state: String?,
        authorizationCodeLength: Int,
        receivedAt: Date = Date(),
        requiresBackendTokenExchange: Bool
    ) {
        self.id = id
        self.providerKey = providerKey
        self.integrationKey = integrationKey
        self.state = state
        self.authorizationCodeLength = authorizationCodeLength
        self.receivedAt = receivedAt
        self.requiresBackendTokenExchange = requiresBackendTokenExchange
    }

    public var settingsStatusText: String {
        let exchange = requiresBackendTokenExchange
            ? KairoL10n.string("settings.oauth.callback.backendExchangeRequired")
            : KairoL10n.string("settings.oauth.callback.readyForTokenExchange")
        return KairoL10n.string(
            "settings.oauth.callback.authorizationCodeReceived",
            providerKey,
            Int64(authorizationCodeLength),
            exchange
        )
    }
}

public enum OAuthConnectorCallbackPreviewError: Error, Equatable {
    case invalidCallbackURL
    case unsupportedCallbackURL
    case unknownProvider(String)
    case authorizationFailed(String)
    case missingCode
}

public actor FileBackedOAuthConnectorCallbackStore {
    private let fileURL: URL
    private var previewsByProviderKey: [String: [OAuthConnectorCallbackPreview]] = [:]

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        try loadFromDisk()
    }

    public func latestPreview(for providerKey: String) -> OAuthConnectorCallbackPreview? {
        previewsByProviderKey[providerKey]?.sorted { $0.receivedAt > $1.receivedAt }.first
    }

    public func allPreviews() -> [OAuthConnectorCallbackPreview] {
        previewsByProviderKey.values
            .flatMap { $0 }
            .sorted { lhs, rhs in
                if lhs.receivedAt == rhs.receivedAt {
                    return lhs.providerKey < rhs.providerKey
                }
                return lhs.receivedAt > rhs.receivedAt
            }
    }

    public func save(_ preview: OAuthConnectorCallbackPreview) throws {
        var previews = previewsByProviderKey[preview.providerKey] ?? []
        previews.removeAll { $0.id == preview.id }
        previews.append(preview)
        previewsByProviderKey[preview.providerKey] = previews
        try persist()
    }

    private func loadFromDisk() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            previewsByProviderKey = [:]
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            previewsByProviderKey = [:]
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([OAuthConnectorCallbackPreview].self, from: data)
        previewsByProviderKey = Dictionary(grouping: decoded, by: \.providerKey)
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(allPreviews())
        try data.write(to: fileURL, options: [.atomic])
    }
}
