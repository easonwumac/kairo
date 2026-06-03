import Foundation

public protocol KairoAccessAPI: Sendable {
    func capabilities() async -> [Capability]
    func status(for capability: CapabilityKey) async -> CapabilityStatus
    func request(_ capability: CapabilityKey) async throws -> CapabilityStatus
}

public struct KairoAccessBackendService: KairoAccessAPI {
    private let capabilityRegistry: CapabilityRegistry
    private let permissionService: any PermissionService

    public init(
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry(),
        permissionService: any PermissionService
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.permissionService = permissionService
    }

    public func capabilities() async -> [Capability] {
        var resolvedCapabilities: [Capability] = []
        resolvedCapabilities.reserveCapacity(capabilityRegistry.capabilities.count)
        for var capability in capabilityRegistry.capabilities {
            capability.status = await permissionService.status(for: capability.key)
            resolvedCapabilities.append(capability)
        }
        return resolvedCapabilities
    }

    public func status(for capability: CapabilityKey) async -> CapabilityStatus {
        await permissionService.status(for: capability)
    }

    public func request(_ capability: CapabilityKey) async throws -> CapabilityStatus {
        try await permissionService.request(capability)
    }
}
