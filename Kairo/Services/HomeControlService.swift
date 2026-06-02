import Foundation

public protocol HomeControlService: Sendable {
    func requestAuthorization() async throws -> Bool
    func execute(_ request: HomeControlRequest) async throws -> String
}

public struct UnavailableHomeControlService: HomeControlService {
    public init() {}

    public func requestAuthorization() async throws -> Bool {
        false
    }

    public func execute(_ request: HomeControlRequest) async throws -> String {
        throw HomeControlError.unavailable
    }
}

public enum HomeControlError: Error, Equatable {
    case unavailable
    case authorizationDenied
    case unsupportedCommand
}
