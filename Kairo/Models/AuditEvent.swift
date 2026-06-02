import Foundation

public struct AuditEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var actionKind: AgentActionKind
    public var memoryIDs: [UUID]
    public var capabilityKeys: [CapabilityKey]
    public var usedCloudModel: Bool
    public var requiredConfirmation: Bool
    public var userConfirmed: Bool
    public var result: AuditResult

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        actionKind: AgentActionKind,
        memoryIDs: [UUID] = [],
        capabilityKeys: [CapabilityKey] = [],
        usedCloudModel: Bool,
        requiredConfirmation: Bool,
        userConfirmed: Bool,
        result: AuditResult
    ) {
        self.id = id
        self.createdAt = createdAt
        self.actionKind = actionKind
        self.memoryIDs = memoryIDs
        self.capabilityKeys = capabilityKeys
        self.usedCloudModel = usedCloudModel
        self.requiredConfirmation = requiredConfirmation
        self.userConfirmed = userConfirmed
        self.result = result
    }
}

public enum AuditResult: String, Codable, Sendable {
    case proposed
    case completed
    case rejected
    case failed
}
