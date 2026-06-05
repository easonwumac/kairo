import Foundation

public protocol AgentToolPlanningRequestBuilding: Sendable {
    func buildToolPlanningRequest(
        message: String,
        attachments: [ChatAttachment],
        privacyMode: ChatPrivacyMode
    ) -> AgentToolInvocationRequest
}

public struct DefaultAgentToolPlanningRequestBuilder: AgentToolPlanningRequestBuilding {
    public init() {}

    public func buildToolPlanningRequest(
        message: String,
        attachments: [ChatAttachment],
        privacyMode: ChatPrivacyMode
    ) -> AgentToolInvocationRequest {
        AgentToolInvocationRequest(
            userText: message,
            matchingText: Self.planningText(message: message, attachments: attachments),
            allowsToolUse: privacyMode != .privateChat
        )
    }

    private static func planningText(message: String, attachments: [ChatAttachment]) -> String {
        let attachmentText = attachments
            .map(\.promptSummary)
            .joined(separator: "\n")
        guard !attachmentText.isEmpty else { return message }
        return [message, attachmentText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
