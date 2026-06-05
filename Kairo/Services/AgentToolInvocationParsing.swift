import Foundation

extension AgentToolInvocationPlanner {
    func normalize(_ value: String) -> String {
        appIntegrationActionParser.normalize(value)
    }

    func uniqueCandidates(_ candidates: [AgentToolInvocationCandidate]) -> [AgentToolInvocationCandidate] {
        var seen: Set<String> = []
        var result: [AgentToolInvocationCandidate] = []

        for candidate in candidates where !seen.contains(candidate.id) {
            seen.insert(candidate.id)
            result.append(candidate)
        }

        return result
    }
}
