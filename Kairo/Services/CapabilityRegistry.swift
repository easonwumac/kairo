import Foundation

public struct CapabilityRegistry: Sendable {
    public var capabilities: [Capability]

    public init(capabilities: [Capability] = CapabilityRegistry.defaultCapabilities) {
        self.capabilities = capabilities
    }

    public static let defaultCapabilities: [Capability] = [
        Capability(
            key: .chat,
            displayName: KairoL10n.string("capability.chat.title"),
            description: KairoL10n.string("capability.chat.description"),
            permission: .none,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .memory,
            displayName: KairoL10n.string("capability.memory.title"),
            description: KairoL10n.string("capability.memory.description"),
            permission: .none,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .shareExtension,
            displayName: KairoL10n.string("capability.shareExtension.title"),
            description: KairoL10n.string("capability.shareExtension.description"),
            permission: .userInitiated,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .appIntents,
            displayName: KairoL10n.string("capability.appIntents.title"),
            description: KairoL10n.string("capability.appIntents.description"),
            permission: .userInitiated,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .integrationRegistry,
            displayName: KairoL10n.string("capability.integrationRegistry.title"),
            description: KairoL10n.string("capability.integrationRegistry.description"),
            permission: .userInitiated,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .backgroundTasks,
            displayName: KairoL10n.string("capability.backgroundTasks.title"),
            description: KairoL10n.string("capability.backgroundTasks.description"),
            permission: .entitlement,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .notifications,
            displayName: KairoL10n.string("capability.notifications.title"),
            description: KairoL10n.string("capability.notifications.description"),
            permission: .runtimePrompt,
            status: .unknown,
            isMVP: true
        ),
        Capability(
            key: .calendar,
            displayName: KairoL10n.string("capability.calendar.title"),
            description: KairoL10n.string("capability.calendar.description"),
            permission: .runtimePrompt,
            status: .unknown,
            isMVP: true
        ),
        Capability(
            key: .reminders,
            displayName: KairoL10n.string("capability.reminders.title"),
            description: KairoL10n.string("capability.reminders.description"),
            permission: .runtimePrompt,
            status: .unknown,
            isMVP: true
        ),
        Capability(
            key: .contacts,
            displayName: KairoL10n.string("capability.contacts.title"),
            description: KairoL10n.string("capability.contacts.description"),
            permission: .runtimePrompt,
            status: .unknown,
            isMVP: false
        ),
        Capability(
            key: .mail,
            displayName: KairoL10n.string("capability.mail.title"),
            description: KairoL10n.string("capability.mail.description"),
            permission: .userInitiated,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .messages,
            displayName: KairoL10n.string("capability.messages.title"),
            description: KairoL10n.string("capability.messages.description"),
            permission: .userInitiated,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .phone,
            displayName: KairoL10n.string("capability.phone.title"),
            description: KairoL10n.string("capability.phone.description"),
            permission: .userInitiated,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .web,
            displayName: KairoL10n.string("capability.web.title"),
            description: KairoL10n.string("capability.web.description"),
            permission: .userInitiated,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .photos,
            displayName: KairoL10n.string("capability.photos.title"),
            description: KairoL10n.string("capability.photos.description"),
            permission: .userInitiated,
            status: .unknown,
            isMVP: true
        ),
        Capability(
            key: .documents,
            displayName: KairoL10n.string("capability.documents.title"),
            description: KairoL10n.string("capability.documents.description"),
            permission: .userInitiated,
            status: .unknown,
            isMVP: true
        ),
        Capability(
            key: .location,
            displayName: KairoL10n.string("capability.location.title"),
            description: KairoL10n.string("capability.location.description"),
            permission: .userInitiated,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .homeKit,
            displayName: KairoL10n.string("capability.homeKit.title"),
            description: KairoL10n.string("capability.homeKit.description"),
            permission: .runtimePrompt,
            status: .unknown,
            isMVP: false
        ),
        Capability(
            key: .externalConnectors,
            displayName: KairoL10n.string("capability.externalConnectors.title"),
            description: KairoL10n.string("capability.externalConnectors.description"),
            permission: .oauth,
            status: .unknown,
            isMVP: false
        )
    ]
}
