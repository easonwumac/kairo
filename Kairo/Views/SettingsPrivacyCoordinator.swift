#if canImport(SwiftUI)
import Foundation

public enum SettingsPrivacyCoordinatorError: Error, Equatable {
    case unavailable
}

public actor SettingsPrivacyCoordinator {
    private let deletionAPI: (any KairoDeletionAPI)?

    public init(deletionAPI: (any KairoDeletionAPI)?) {
        self.deletionAPI = deletionAPI
    }

    public func clearAuditLog() async throws {
        guard let deletionAPI else {
            throw SettingsPrivacyCoordinatorError.unavailable
        }
        try await deletionAPI.clearAuditLog()
    }
}
#endif
