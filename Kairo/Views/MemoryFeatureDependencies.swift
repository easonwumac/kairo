#if canImport(SwiftUI)
import Foundation

public struct MemoryFeatureDependencies {
    public var memoryAPI: any KairoMemoryAPI

    public init(memoryAPI: (any KairoMemoryAPI)? = nil) {
        self.memoryAPI = memoryAPI ?? UnavailableMemoryAPI()
    }
}

public struct MemoryFeatureDependencyFactory: Sendable {
    public init() {}

    public func makeDependencies(
        memoryAPI: (any KairoMemoryAPI)? = nil
    ) -> MemoryFeatureDependencies {
        MemoryFeatureDependencies(memoryAPI: memoryAPI)
    }
}

private struct UnavailableMemoryAPI: KairoMemoryAPI {
    func list(limit: Int) async throws -> [MemoryRecord] {
        throw MemoryFeatureDependencyError.memoryAPIUnavailable
    }

    func search(query: String, limit: Int) async throws -> [MemoryRecord] {
        throw MemoryFeatureDependencyError.memoryAPIUnavailable
    }

    func save(_ memory: MemoryRecord) async throws {
        throw MemoryFeatureDependencyError.memoryAPIUnavailable
    }

    func delete(id: UUID) async throws {
        throw MemoryFeatureDependencyError.memoryAPIUnavailable
    }

    func erase(id: UUID) async throws {
        throw MemoryFeatureDependencyError.memoryAPIUnavailable
    }

    func purgeDeleted() async throws {
        throw MemoryFeatureDependencyError.memoryAPIUnavailable
    }

    func export(limit: Int) async throws -> MemoryExport {
        throw MemoryFeatureDependencyError.memoryAPIUnavailable
    }
}

private enum MemoryFeatureDependencyError: LocalizedError {
    case memoryAPIUnavailable

    var errorDescription: String? {
        "memory.api.unavailable"
    }
}

public extension KairoEnvironment {
    var memoryFeatureDependencies: MemoryFeatureDependencies {
        MemoryFeatureDependencyFactory().makeDependencies(memoryAPI: backendAPI.memory)
    }
}
#endif
