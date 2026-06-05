#if canImport(SwiftUI)
import Foundation

public struct MemoryFeatureDependencies {
    public var memoryAPI: any KairoMemoryAPI

    public init(memoryAPI: any KairoMemoryAPI = KairoMemoryBackendService(memoryStore: InMemoryMemoryStore())) {
        self.memoryAPI = memoryAPI
    }
}

public extension KairoEnvironment {
    var memoryFeatureDependencies: MemoryFeatureDependencies {
        MemoryFeatureDependencies(memoryAPI: backendAPI.memory)
    }
}
#endif
