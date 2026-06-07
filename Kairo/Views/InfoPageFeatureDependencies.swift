import Foundation

public struct InfoPageFeatureDependencies {
    public var store: any InfoPageStore

    public init(store: (any InfoPageStore)? = nil) {
        self.store = store ?? InMemoryInfoPageStore()
    }
}

public struct InfoPageFeatureDependencyFactory: Sendable {
    public init() {}

    public func makeDependencies(store: (any InfoPageStore)? = nil) -> InfoPageFeatureDependencies {
        InfoPageFeatureDependencies(store: store)
    }
}

public extension KairoEnvironment {
    var infoPageFeatureDependencies: InfoPageFeatureDependencies {
        InfoPageFeatureDependencyFactory().makeDependencies()
    }
}
