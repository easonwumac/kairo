import Foundation

public struct ChatProviderRouteStatus: Equatable, Sendable {
    public var title: String
    public var detail: String
    public var badge: String
    public var warning: String?
    public var preference: ProviderRoutePreference?
    public var selectedOptionID: String?
    public var options: [ChatProviderRouteOption]

    public init(
        title: String,
        detail: String,
        badge: String,
        warning: String? = nil,
        preference: ProviderRoutePreference? = nil,
        selectedOptionID: String? = nil,
        options: [ChatProviderRouteOption] = []
    ) {
        self.title = title
        self.detail = detail
        self.badge = badge
        self.warning = warning
        self.preference = preference
        self.selectedOptionID = selectedOptionID
        self.options = options
    }
}

public struct ChatProviderRouteOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let sourceTitle: String
    public let detail: String
    public let systemImage: String
    public let preference: ProviderRoutePreference
    public let modelID: String?
    public let isEnabled: Bool

    public init(
        id: String,
        title: String,
        sourceTitle: String,
        detail: String,
        systemImage: String,
        preference: ProviderRoutePreference,
        modelID: String? = nil,
        isEnabled: Bool
    ) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
        self.detail = detail
        self.systemImage = systemImage
        self.preference = preference
        self.modelID = modelID
        self.isEnabled = isEnabled
    }
}

public enum ChatProviderRouteStatusBuilder {
    public static func build(
        from status: LocalModelSettingsStatus?,
        openAIStatus: OpenAISettingsStatus? = nil,
        localRuntimeAvailable: Bool = false
    ) -> ChatProviderRouteStatus {
        let cloudWarning = cloudProviderWarning(from: openAIStatus)
        let cloudOption = makeCloudOption(openAIStatus: openAIStatus)
        guard let status else {
            return ChatProviderRouteStatus(
                title: cloudOption.title,
                detail: cloudProviderDetail(from: openAIStatus),
                badge: cloudOption.sourceTitle,
                warning: cloudWarning,
                selectedOptionID: cloudOption.id,
                options: [cloudOption]
            )
        }

        let localOptions = makeLocalOptions(from: status, localRuntimeAvailable: localRuntimeAvailable)
        let options = [cloudOption] + localOptions
        let selectedOptionID = selectedOptionID(for: status, fallback: cloudOption.id)
        let selectedOption = options.first { $0.id == selectedOptionID } ?? cloudOption
        let selectedModelName = status.selectedModel?.displayName ?? status.selectedModelID

        let detail: String
        switch status.preference {
        case .preferCloud:
            detail = KairoL10n.string("chat.provider.detail.preferCloud")
        case .localOnly:
            if status.localModelInstalled, let selectedModelName {
                detail = localRuntimeAvailable
                    ? KairoL10n.string("chat.provider.detail.localOnlyInstalledAvailable", selectedModelName)
                    : KairoL10n.string("chat.provider.detail.localOnlyInstalledUnavailable", selectedModelName)
            } else {
                detail = KairoL10n.string("chat.provider.detail.localOnlyNeedsModel")
            }
        case .automatic, .preferLocal:
            if status.localModelInstalled, let selectedModelName {
                detail = localRuntimeAvailable
                    ? KairoL10n.string("chat.provider.detail.localSelectedAvailable", selectedModelName)
                    : KairoL10n.string("chat.provider.detail.localSelectedUnavailable", selectedModelName)
            } else if selectedModelName != nil {
                detail = KairoL10n.string("chat.provider.detail.localSelectedNotInstalled")
            } else {
                detail = KairoL10n.string("chat.provider.detail.noLocalModel")
            }
        }

        let warning: String?
        if status.preference == .localOnly && status.localModelInstalled && !localRuntimeAvailable {
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
            title: selectedOption.title,
            detail: detail,
            badge: selectedOption.sourceTitle,
            warning: warning,
            preference: status.preference,
            selectedOptionID: selectedOption.id,
            options: options
        )
    }

    private static func makeCloudOption(openAIStatus: OpenAISettingsStatus?) -> ChatProviderRouteOption {
        let providerName = openAIStatus?.providerName ?? "OpenAI"
        let hasAPIKey = openAIStatus?.hasAPIKey == true
        return ChatProviderRouteOption(
            id: "cloud.openai",
            title: providerName,
            sourceTitle: KairoL10n.string("chat.provider.source.cloud"),
            detail: hasAPIKey
                ? KairoL10n.string("chat.provider.detail.cloudConfigured", providerName)
                : KairoL10n.string("chat.provider.detail.cloudKeyMissing", providerName),
            systemImage: hasAPIKey ? "checkmark.seal.fill" : "key.fill",
            preference: .preferCloud,
            isEnabled: hasAPIKey
        )
    }

    private static func makeLocalOptions(
        from status: LocalModelSettingsStatus,
        localRuntimeAvailable: Bool
    ) -> [ChatProviderRouteOption] {
        let installedRecordsByID = Dictionary(uniqueKeysWithValues: status.installedModels.map { ($0.modelID, $0) })
        let installedModels = status.availableModels.filter { model in
            installedRecordsByID[model.id]?.status == .installed
        }
        guard !installedModels.isEmpty else {
            return [
                ChatProviderRouteOption(
                    id: "local.none",
                    title: KairoL10n.string("chat.provider.localModelUnavailable.title"),
                    sourceTitle: KairoL10n.string("chat.provider.source.local"),
                    detail: KairoL10n.string("chat.provider.detail.localOnlyNeedsModel"),
                    systemImage: "arrow.down.circle",
                    preference: .localOnly,
                    isEnabled: false
                )
            ]
        }
        return installedModels.map { model in
            ChatProviderRouteOption(
                id: "local.\(model.id)",
                title: model.displayName,
                sourceTitle: KairoL10n.string("chat.provider.source.local"),
                detail: localRuntimeAvailable
                    ? KairoL10n.string("chat.provider.detail.localOnlyInstalledAvailable", model.displayName)
                    : KairoL10n.string("chat.provider.detail.localOnlyInstalledUnavailable", model.displayName),
                systemImage: localRuntimeAvailable ? "cpu.fill" : "exclamationmark.triangle.fill",
                preference: .localOnly,
                modelID: model.id,
                isEnabled: localRuntimeAvailable
            )
        }
    }

    private static func selectedOptionID(for status: LocalModelSettingsStatus, fallback: String) -> String {
        switch status.preference {
        case .localOnly, .preferLocal:
            if let selectedModelID = status.selectedModelID {
                return "local.\(selectedModelID)"
            }
            return "local.none"
        case .automatic, .preferCloud:
            return fallback
        }
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

}

public extension ProviderRoutePreference {
    var chatControlTitle: String {
        switch self {
        case .automatic:
            return KairoL10n.string("chat.provider.route.auto")
        case .preferLocal:
            return KairoL10n.string("chat.provider.route.local")
        case .preferCloud:
            return KairoL10n.string("chat.provider.route.cloud")
        case .localOnly:
            return KairoL10n.string("chat.provider.route.only")
        }
    }
}
