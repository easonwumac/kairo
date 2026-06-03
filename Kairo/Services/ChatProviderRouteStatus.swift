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
    public static func build(from status: LocalModelSettingsStatus?) -> ChatProviderRouteStatus {
        guard let status else {
            return ChatProviderRouteStatus(
                title: "Route: Cloud",
                detail: "Using the configured app provider. Local model settings are not available for this chat surface.",
                badge: "Cloud"
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
                detail = "Local Only uses \(selectedModelName) for eligible local work. Tools and current info fail closed."
            } else {
                detail = "Local Only is active. Download and select a local model before chat can answer locally."
            }
        case .automatic, .preferLocal:
            if status.localModelInstalled, let selectedModelName {
                detail = "Selected local model: \(selectedModelName). Eligible private/offline work can route locally; tools and current info stay cloud or visible handoff."
            } else if selectedModelName != nil {
                detail = "Selected local model is not installed yet. Download it before local routing can answer."
            } else {
                detail = "No local model selected. General chat uses the configured cloud provider when policy allows."
            }
        }

        let warning: String?
        if status.preference == .localOnly && !status.localModelInstalled {
            warning = "Local Only is active but no downloaded model is selected."
        } else if status.preference == .preferLocal && !status.localModelInstalled {
            warning = "Prefer Local needs a downloaded selected model before private/offline work can route locally."
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
