import Foundation

public protocol AgentToolCandidateFiltering: Sendable {
    func allowsCandidate(_ candidate: AgentToolInvocationCandidate) -> Bool
}

public struct PhoneToolCandidateFilter: AgentToolCandidateFiltering {
    private let actionGate: any PhoneToolActionGating
    private let policyProvider: any CapabilityToolPolicyProviding
    private let capabilityRegistry: any CapabilityRegistryProviding

    public init(
        actionGate: any PhoneToolActionGating = BuiltInPhoneToolActionGate(),
        policyProvider: any CapabilityToolPolicyProviding = DefaultCapabilityToolPolicyProvider(),
        capabilityRegistry: any CapabilityRegistryProviding = CapabilityRegistry()
    ) {
        self.actionGate = actionGate
        self.policyProvider = policyProvider
        self.capabilityRegistry = capabilityRegistry
    }

    public func allowsCandidate(_ candidate: AgentToolInvocationCandidate) -> Bool {
        guard requiredCapabilitiesAreAllowed(candidate.requiredCapabilities) else {
            return false
        }
        guard let action = candidate.action else {
            return true
        }
        return actionGate.allowsExecutablePreview(action)
    }

    private func requiredCapabilitiesAreAllowed(_ capabilityKeys: [CapabilityKey]) -> Bool {
        for capabilityKey in capabilityKeys {
            let permission = capabilityRegistry.capabilities.first { $0.key == capabilityKey }?.permission ?? .userInitiated
            if policyProvider.policy(for: capabilityKey, permission: permission) == .deny {
                return false
            }
        }
        return true
    }
}
