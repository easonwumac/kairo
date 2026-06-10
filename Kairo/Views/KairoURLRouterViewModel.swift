#if canImport(SwiftUI)
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class KairoURLRouterViewModel {
    public private(set) var pending: KairoURLRoute?
    public private(set) var router: KairoURLRouter

    public init(router: KairoURLRouter) {
        self.router = router
    }

    public func handle(_ url: URL) {
        guard let route = router.parse(url) else { return }
        pending = route
    }

    public func reanchor(to router: KairoURLRouter) {
        guard self.router.scheme != router.scheme else { return }
        self.router = router
    }

    public func consume() -> KairoURLRoute? {
        let route = pending
        pending = nil
        return route
    }

    public func navigate(to route: KairoURLRoute) {
        pending = route
    }
}
#endif
