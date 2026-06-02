import Foundation

public struct SafetyPolicyDecision: Equatable, Sendable {
    public var allowed: Bool
    public var requiresConfirmation: Bool
    public var reason: String

    public init(allowed: Bool, requiresConfirmation: Bool, reason: String) {
        self.allowed = allowed
        self.requiresConfirmation = requiresConfirmation
        self.reason = reason
    }
}

public struct SafetyPolicyEngine: Sendable {
    public init() {}

    public func evaluate(_ action: AgentAction) -> SafetyPolicyDecision {
        if action.kind == .unsupportedSandboxAction {
            return SafetyPolicyDecision(
                allowed: true,
                requiresConfirmation: false,
                reason: "此項目只用來說明 iOS sandbox 或公開 API 不支援的操作，不會執行外部動作。"
            )
        }

        switch action.riskTier {
        case .tier0ReadOnly:
            return SafetyPolicyDecision(
                allowed: true,
                requiresConfirmation: false,
                reason: "只讀或建議型操作，可直接執行。"
            )
        case .tier1Draft:
            return SafetyPolicyDecision(
                allowed: true,
                requiresConfirmation: true,
                reason: "草稿型操作需要使用者確認。"
            )
        case .tier2LowRiskWrite:
            return SafetyPolicyDecision(
                allowed: true,
                requiresConfirmation: true,
                reason: "低風險寫入仍需確認，避免 Agent 誤寫資料。"
            )
        case .tier3HighRiskExternal:
            return SafetyPolicyDecision(
                allowed: true,
                requiresConfirmation: true,
                reason: "高風險外部操作必須預覽並明確確認。"
            )
        }
    }
}
