import Foundation

public protocol AgentToolCandidateFiltering: Sendable {
    func allowsCandidate(_ candidate: AgentToolInvocationCandidate) -> Bool
}

public struct PhoneToolCandidateFilter: AgentToolCandidateFiltering {
    private let actionGate: any PhoneToolActionGating

    public init(actionGate: any PhoneToolActionGating = BuiltInPhoneToolActionGate()) {
        self.actionGate = actionGate
    }

    public func allowsCandidate(_ candidate: AgentToolInvocationCandidate) -> Bool {
        guard let action = candidate.action else {
            return true
        }
        return actionGate.allowsExecutablePreview(action)
    }
}
