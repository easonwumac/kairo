import Foundation

public struct ChatProviderRouteStatus: Equatable, Sendable {
    public var title: String
    public var detail: String
    public var badge: String
    public var warning: String?
    public var preference: ProviderRoutePreference?

    public init(
        title: String,
        detail: String,
        badge: String,
        warning: String? = nil,
        preference: ProviderRoutePreference? = nil
    ) {
        self.title = title
        self.detail = detail
        self.badge = badge
        self.warning = warning
        self.preference = preference
    }
}

public enum ChatProviderRouteStatusBuilder {
    public static func build(
        from status: LocalModelSettingsStatus?,
        openAIStatus: OpenAISettingsStatus? = nil
    ) -> ChatProviderRouteStatus {
        let cloudWarning = cloudProviderWarning(from: openAIStatus)
        guard let status else {
            return ChatProviderRouteStatus(
                title: "Route: Cloud",
                detail: cloudProviderDetail(from: openAIStatus),
                badge: "Cloud",
                warning: cloudWarning
            )
        }

        let selectedModelName = status.selectedModel?.displayName ?? status.selectedModelID
        let badge: String
        switch status.preference {
        case .automatic:
            badge = "Auto"
        case .preferLocal:
            badge = "Local"
        case .preferCloud:
            badge = "Cloud"
        case .localOnly:
            badge = "Local only"
        }

        let detail: String
        switch status.preference {
        case .preferCloud:
            detail = "Cloud routing is preferred for chat. Local models stay available only after switching route preference."
        case .localOnly:
            if status.localModelInstalled, let selectedModelName {
                detail = "Local Only selected \(selectedModelName), but iOS production local inference is not available in this beta. Chat fails closed instead of pretending the phone can answer locally."
            } else {
                detail = "Local Only is active. Download and select a local model before chat can answer locally."
            }
        case .automatic, .preferLocal:
            if status.localModelInstalled, let selectedModelName {
                detail = "Selected local model: \(selectedModelName). Catalog/download/select/delete are available; iOS production local inference remains unavailable until a runtime is implemented and verified on device."
            } else if selectedModelName != nil {
                detail = "Selected local model is not installed yet. Download it before local routing can answer."
            } else {
                detail = "No local model selected. General chat uses the configured cloud provider when policy allows."
            }
        }

        let warning: String?
        if status.preference == .localOnly && status.localModelInstalled {
            warning = "iOS production local inference is unavailable in this beta."
        } else if status.preference == .localOnly && !status.localModelInstalled {
            warning = "Local Only is active but no downloaded model is selected."
        } else if status.preference == .preferLocal && !status.localModelInstalled {
            warning = "Prefer Local needs a downloaded selected model before private/offline work can route locally."
        } else if status.preference != .localOnly {
            warning = cloudWarning
        } else {
            warning = nil
        }

        return ChatProviderRouteStatus(
            title: "Route: \(status.preference.settingsTitle)",
            detail: detail,
            badge: badge,
            warning: warning,
            preference: status.preference
        )
    }

    private static func cloudProviderDetail(from status: OpenAISettingsStatus?) -> String {
        guard let status else {
            return "Cloud provider route is available for this chat surface. Save an OpenAI API key in Settings before sending cloud chat."
        }
        if status.hasAPIKey {
            return "\(status.providerName) is configured for cloud chat."
        }
        return "\(status.providerName) API key is not saved. Chat will fail closed until Settings has a key or a supported local route is selected."
    }

    private static func cloudProviderWarning(from status: OpenAISettingsStatus?) -> String? {
        guard let status, !status.hasAPIKey else { return nil }
        return "\(status.providerName) API key is not saved."
    }
}

public extension ProviderRoutePreference {
    var chatControlTitle: String {
        switch self {
        case .automatic:
            return "Auto"
        case .preferLocal:
            return "Local"
        case .preferCloud:
            return "Cloud"
        case .localOnly:
            return "Only"
        }
    }
}
