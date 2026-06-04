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
                title: KairoL10n.string("chat.provider.route.title", KairoL10n.string("chat.provider.route.cloud")),
                detail: cloudProviderDetail(from: openAIStatus),
                badge: KairoL10n.string("chat.provider.route.cloud"),
                warning: cloudWarning
            )
        }

        let selectedModelName = status.selectedModel?.displayName ?? status.selectedModelID
        let badge: String
        switch status.preference {
        case .automatic:
            badge = KairoL10n.string("chat.provider.route.auto")
        case .preferLocal:
            badge = KairoL10n.string("chat.provider.route.local")
        case .preferCloud:
            badge = KairoL10n.string("chat.provider.route.cloud")
        case .localOnly:
            badge = KairoL10n.string("chat.provider.route.localOnly")
        }

        let detail: String
        switch status.preference {
        case .preferCloud:
            detail = KairoL10n.string("chat.provider.detail.preferCloud")
        case .localOnly:
            if status.localModelInstalled, let selectedModelName {
                detail = KairoL10n.string("chat.provider.detail.localOnlyInstalledUnavailable", selectedModelName)
            } else {
                detail = KairoL10n.string("chat.provider.detail.localOnlyNeedsModel")
            }
        case .automatic, .preferLocal:
            if status.localModelInstalled, let selectedModelName {
                detail = KairoL10n.string("chat.provider.detail.localSelectedUnavailable", selectedModelName)
            } else if selectedModelName != nil {
                detail = KairoL10n.string("chat.provider.detail.localSelectedNotInstalled")
            } else {
                detail = KairoL10n.string("chat.provider.detail.noLocalModel")
            }
        }

        let warning: String?
        if status.preference == .localOnly && status.localModelInstalled {
            warning = KairoL10n.string("chat.provider.warning.localInferenceUnavailable")
        } else if status.preference == .localOnly && !status.localModelInstalled {
            warning = KairoL10n.string("chat.provider.warning.localOnlyNoModel")
        } else if status.preference == .preferLocal && !status.localModelInstalled {
            warning = KairoL10n.string("chat.provider.warning.preferLocalNoModel")
        } else if status.preference != .localOnly {
            warning = cloudWarning
        } else {
            warning = nil
        }

        return ChatProviderRouteStatus(
            title: KairoL10n.string("chat.provider.route.title", localizedPreferenceTitle(for: status.preference)),
            detail: detail,
            badge: badge,
            warning: warning,
            preference: status.preference
        )
    }

    private static func cloudProviderDetail(from status: OpenAISettingsStatus?) -> String {
        guard let status else {
            return KairoL10n.string("chat.provider.detail.cloudNeedsKey")
        }
        if status.hasAPIKey {
            return KairoL10n.string("chat.provider.detail.cloudConfigured", status.providerName)
        }
        return KairoL10n.string("chat.provider.detail.cloudKeyMissing", status.providerName)
    }

    private static func cloudProviderWarning(from status: OpenAISettingsStatus?) -> String? {
        guard let status, !status.hasAPIKey else { return nil }
        return KairoL10n.string("chat.provider.warning.openAIKeyMissing", status.providerName)
    }

    private static func localizedPreferenceTitle(for preference: ProviderRoutePreference) -> String {
        switch preference {
        case .automatic:
            return KairoL10n.string("chat.provider.route.auto")
        case .preferLocal:
            return KairoL10n.string("chat.provider.route.local")
        case .preferCloud:
            return KairoL10n.string("chat.provider.route.cloud")
        case .localOnly:
            return KairoL10n.string("chat.provider.route.localOnly")
        }
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
