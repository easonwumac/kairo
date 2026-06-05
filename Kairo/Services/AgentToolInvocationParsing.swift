import Foundation

extension AgentToolInvocationPlanner {
    func normalize(_ value: String) -> String {
        dependencies.appIntegrationActionParser.normalize(value)
    }
}
