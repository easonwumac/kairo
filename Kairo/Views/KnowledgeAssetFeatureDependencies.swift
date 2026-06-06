#if canImport(SwiftUI)
import Foundation

public struct KnowledgeAssetFeatureDependencies {
    public var assetAPI: any KairoKnowledgeAssetAPI

    public init(assetAPI: (any KairoKnowledgeAssetAPI)? = nil) {
        self.assetAPI = assetAPI ?? UnavailableKnowledgeAssetAPI()
    }
}

public struct KnowledgeAssetFeatureDependencyFactory: Sendable {
    public init() {}

    public func makeDependencies(
        assetAPI: (any KairoKnowledgeAssetAPI)? = nil
    ) -> KnowledgeAssetFeatureDependencies {
        KnowledgeAssetFeatureDependencies(assetAPI: assetAPI)
    }
}

private struct UnavailableKnowledgeAssetAPI: KairoKnowledgeAssetAPI {
    func importPendingShares(limit: Int, iCloudBackupAllowed: Bool) async throws -> KairoKnowledgeAssetImportResult {
        throw KnowledgeAssetFeatureDependencyError.assetAPIUnavailable
    }

    func list(limit: Int) async throws -> [KnowledgeAsset] {
        throw KnowledgeAssetFeatureDependencyError.assetAPIUnavailable
    }

    func search(query: String, limit: Int) async throws -> [KnowledgeAsset] {
        throw KnowledgeAssetFeatureDependencyError.assetAPIUnavailable
    }

    func query(_ query: KnowledgeAssetQuery, limit: Int) async throws -> [KnowledgeAsset] {
        throw KnowledgeAssetFeatureDependencyError.assetAPIUnavailable
    }

    func save(_ asset: KnowledgeAsset) async throws {
        throw KnowledgeAssetFeatureDependencyError.assetAPIUnavailable
    }

    func delete(id: UUID) async throws {
        throw KnowledgeAssetFeatureDependencyError.assetAPIUnavailable
    }

    func listFolders() async throws -> [KnowledgeAssetFolder] {
        throw KnowledgeAssetFeatureDependencyError.assetAPIUnavailable
    }

    func saveFolder(_ folder: KnowledgeAssetFolder) async throws {
        throw KnowledgeAssetFeatureDependencyError.assetAPIUnavailable
    }

    func deleteFolder(id: UUID) async throws {
        throw KnowledgeAssetFeatureDependencyError.assetAPIUnavailable
    }

    func export(limit: Int) async throws -> KnowledgeAssetExport {
        throw KnowledgeAssetFeatureDependencyError.assetAPIUnavailable
    }
}

private enum KnowledgeAssetFeatureDependencyError: LocalizedError {
    case assetAPIUnavailable

    var errorDescription: String? {
        "knowledgeAssets.api.unavailable"
    }
}

public extension KairoEnvironment {
    var knowledgeAssetFeatureDependencies: KnowledgeAssetFeatureDependencies {
        KnowledgeAssetFeatureDependencyFactory().makeDependencies(assetAPI: backendAPI.knowledgeAssets)
    }
}
#endif
