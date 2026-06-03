import Foundation

public extension KairoEnvironment {
    var backendAPI: KairoBackendAPI {
        KairoBackendModuleComposer(dependencies: self).makeBackendAPI()
    }
}
