import Foundation

extension SandboxActionExecutor {
    func recordAuditEvent(
        for action: AgentAction,
        decision: SafetyPolicyDecision,
        confirmed: Bool,
        executionResult: ActionExecutionResult
    ) async throws {
        let result: AuditResult
        if executionResult.completed {
            result = .completed
        } else if !decision.allowed || (decision.requiresConfirmation && !confirmed) {
            result = .rejected
        } else {
            result = .failed
        }
        try await recordAuditEvent(for: action, decision: decision, confirmed: confirmed, result: result)
    }

    func recordAuditEvent(
        for action: AgentAction,
        decision: SafetyPolicyDecision,
        confirmed: Bool,
        result: AuditResult
    ) async throws {
        guard let auditLogger else { return }
        try await auditLogger.record(AuditEvent(
            actionKind: action.kind,
            capabilityKeys: Self.capabilityKeys(for: action.kind),
            usedCloudModel: false,
            requiredConfirmation: decision.requiresConfirmation,
            userConfirmed: confirmed,
            result: result
        ))
    }

    static func capabilityKeys(for actionKind: AgentActionKind) -> [CapabilityKey] {
        switch actionKind {
        case .answer:
            return [.chat]
        case .saveMemory:
            return [.memory]
        case .createReminderDraft:
            return [.reminders]
        case .createCalendarDraft:
            return [.calendar]
        case .createContactDraft:
            return [.contacts]
        case .composeEmailDraft:
            return [.mail]
        case .openMapDirections:
            return [.web]
        case .openMessageHandoff:
            return [.messages]
        case .openPhoneCallHandoff:
            return [.phone]
        case .openWebSearchHandoff, .openURL:
            return [.web]
        case .sendNotification:
            return [.notifications]
        case .controlHome:
            return [.homeKit]
        case .externalAPIRequest:
            return [.externalConnectors]
        case .unsupportedSandboxAction:
            return []
        }
    }
}
