import Foundation

public struct Capability: Identifiable, Codable, Equatable, Sendable {
    public var id: String { key.rawValue }
    public var key: CapabilityKey
    public var displayName: String
    public var description: String
    public var permission: PermissionRequirement
    public var status: CapabilityStatus
    public var isMVP: Bool

    public init(
        key: CapabilityKey,
        displayName: String,
        description: String,
        permission: PermissionRequirement,
        status: CapabilityStatus = .unknown,
        isMVP: Bool
    ) {
        self.key = key
        self.displayName = displayName
        self.description = description
        self.permission = permission
        self.status = status
        self.isMVP = isMVP
    }
}

public enum CapabilityKey: String, Codable, CaseIterable, Sendable {
    case chat
    case memory
    case shareExtension
    case appIntents
    case notifications
    case calendar
    case reminders
    case contacts
    case photos
    case documents
    case location
    case externalConnectors
}

public enum PermissionRequirement: String, Codable, Sendable {
    case none
    case userInitiated
    case runtimePrompt
    case entitlement
    case oauth
    case unsupported
}

public enum CapabilityStatus: String, Codable, Sendable {
    case unknown
    case available
    case denied
    case restricted
    case unsupported
}
