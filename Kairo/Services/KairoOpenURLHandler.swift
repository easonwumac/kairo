import Foundation

public protocol KairoOpenURLHandling: Sendable {
    func handle(_ url: URL) async throws
}

public actor OAuthConnectorCallbackOpenURLHandler: KairoOpenURLHandling {
    private let loginService: any OAuthConnectorLoginServicing

    public init(loginService: any OAuthConnectorLoginServicing) {
        self.loginService = loginService
    }

    public func handle(_ url: URL) async throws {
        _ = try await loginService.previewCallback(url)
    }
}
