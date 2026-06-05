import Foundation

public protocol AgentFallbackActionCandidateAppending: Sendable {
    func appendFallbackCandidates(
        to candidates: inout [AgentToolInvocationCandidate],
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing,
        visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding,
        writeActionCandidateProvider: any AgentWriteActionCandidateProviding
    )
}

public struct DefaultAgentFallbackActionCandidateAppender: AgentFallbackActionCandidateAppending {
    public init() {}

    public func appendFallbackCandidates(
        to candidates: inout [AgentToolInvocationCandidate],
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing,
        visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding,
        writeActionCandidateProvider: any AgentWriteActionCandidateProviding
    ) {
        for handoffCandidate in visibleHandoffCandidateProvider.candidates(
            userText: userText,
            normalizedText: normalizedText,
            parser: parser
        ) where !candidates.containsAction(kind: handoffCandidate.action?.kind) {
            candidates.append(handoffCandidate)
        }

        for writeCandidate in writeActionCandidateProvider.candidates(
            userText: userText,
            normalizedText: normalizedText,
            parser: parser
        ) where !candidates.containsAction(kind: writeCandidate.action?.kind) {
            candidates.append(writeCandidate)
        }
    }
}
