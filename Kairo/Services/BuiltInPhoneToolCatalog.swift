import Foundation

public protocol BuiltInPhoneToolCatalogProviding: Sendable {
    var tools: [BuiltInPhoneToolDefinition] { get }
}

public extension BuiltInPhoneToolCatalogProviding {
    func tool(for actionKind: AgentActionKind) -> BuiltInPhoneToolDefinition? {
        tools.first { $0.sourceBinding.agentActionKinds.contains(actionKind) }
    }

    func tool(for shortcutNodeKind: ShortcutNodeKind) -> BuiltInPhoneToolDefinition? {
        tools.first { $0.sourceBinding.shortcutNodeKinds.contains(shortcutNodeKind) }
    }

    func tool(for recipeStepKind: KairoRecipeStepKind) -> BuiltInPhoneToolDefinition? {
        tools.first { $0.sourceBinding.recipeStepKinds.contains(recipeStepKind) }
    }
}

public enum BuiltInPhoneToolID: String, Codable, CaseIterable, Sendable, Identifiable {
    case memorySave = "memory.save"
    case memorySearch = "memory.search"
    case memoryDelete = "memory.delete"
    case memoryExport = "memory.export"
    case shareImport = "share.import"
    case reminderWrite = "reminder.write"
    case calendarWrite = "calendar.write"
    case notificationSchedule = "notification.schedule"
    case contactCreate = "contact.create"
    case emailHandoff = "email.handoff"
    case messageHandoff = "message.handoff"
    case phoneHandoff = "phone.handoff"
    case webSearchHandoff = "web.search.handoff"
    case mapsDirectionsHandoff = "maps.directions.handoff"
    case recipeRun = "recipe.run"
    case shortcutNodeInvocation = "shortcut.node.invoke"
    case oauthConnectorSetupStatus = "oauth.connector.setupStatus"
    case localModelManage = "localModel.manage"
    case homeKitPreview = "homeKit.preview"

    public var id: String { rawValue }
}

public enum BuiltInPhoneToolCategory: String, Codable, CaseIterable, Sendable {
    case memory
    case share
    case reminders
    case calendar
    case notifications
    case contacts
    case handoff
    case recipe
    case shortcuts
    case integrations
    case localModels
    case home
}

public enum BuiltInPhoneToolAvailabilityStatus: String, Codable, CaseIterable, Sendable {
    case available
    case permissionRequired
    case setupRequired
    case scaffolded
    case unsupported

    public var allowsExecutableSuggestion: Bool {
        switch self {
        case .available, .permissionRequired, .setupRequired, .scaffolded:
            return true
        case .unsupported:
            return false
        }
    }
}

public enum BuiltInPhoneToolConfirmationPolicy: String, Codable, CaseIterable, Sendable {
    case notRequired
    case previewRequired
    case previewAndExplicitConfirmation
    case manualSetupOnly

    public var allowsExecutionWithoutConfirmation: Bool {
        self == .notRequired
    }
}

public enum BuiltInPhoneToolExecutionKind: String, Codable, CaseIterable, Sendable {
    case readOnly
    case draftOnly
    case confirmedWrite
    case visibleHandoff
    case setupStatusOnly
    case scaffoldPreviewOnly
}

public struct BuiltInPhoneToolSchema: Codable, Equatable, Sendable {
    public var input: String
    public var output: String

    public init(input: String, output: String) {
        self.input = input
        self.output = output
    }
}

public struct BuiltInPhoneToolLifecycleBinding: Codable, Equatable, Sendable {
    public var previewRenderer: String
    public var executor: String

    public init(previewRenderer: String, executor: String) {
        self.previewRenderer = previewRenderer
        self.executor = executor
    }
}

public struct BuiltInPhoneToolAuditMetadata: Codable, Equatable, Sendable {
    public var capabilityKeys: [CapabilityKey]
    public var sensitivePayloadPolicy: String

    public init(capabilityKeys: [CapabilityKey], sensitivePayloadPolicy: String = "redactedPayloadOnly") {
        self.capabilityKeys = capabilityKeys
        self.sensitivePayloadPolicy = sensitivePayloadPolicy
    }
}

public struct BuiltInPhoneToolFallback: Codable, Equatable, Sendable {
    public var unsupportedReason: String
    public var safeAlternative: String

    public init(unsupportedReason: String, safeAlternative: String) {
        self.unsupportedReason = unsupportedReason
        self.safeAlternative = safeAlternative
    }
}

public struct BuiltInPhoneToolSourceBinding: Codable, Equatable, Sendable {
    public var agentActionKinds: [AgentActionKind]
    public var shortcutNodeKinds: [ShortcutNodeKind]
    public var recipeStepKinds: [KairoRecipeStepKind]
    public var skillKinds: [AgentSkillKind]

    public init(
        agentActionKinds: [AgentActionKind] = [],
        shortcutNodeKinds: [ShortcutNodeKind] = [],
        recipeStepKinds: [KairoRecipeStepKind] = [],
        skillKinds: [AgentSkillKind] = []
    ) {
        self.agentActionKinds = agentActionKinds
        self.shortcutNodeKinds = shortcutNodeKinds
        self.recipeStepKinds = recipeStepKinds
        self.skillKinds = skillKinds
    }
}

public struct BuiltInPhoneToolDefinition: Identifiable, Codable, Equatable, Sendable {
    public var id: BuiltInPhoneToolID
    public var displayName: String
    public var category: BuiltInPhoneToolCategory
    public var schema: BuiltInPhoneToolSchema
    public var permissionRequirement: PermissionRequirement
    public var availabilityStatus: BuiltInPhoneToolAvailabilityStatus
    public var riskTier: ActionRiskTier
    public var confirmationPolicy: BuiltInPhoneToolConfirmationPolicy
    public var executionKind: BuiltInPhoneToolExecutionKind
    public var lifecycle: BuiltInPhoneToolLifecycleBinding
    public var audit: BuiltInPhoneToolAuditMetadata
    public var fallback: BuiltInPhoneToolFallback
    public var sourceBinding: BuiltInPhoneToolSourceBinding

    public init(
        id: BuiltInPhoneToolID,
        displayName: String,
        category: BuiltInPhoneToolCategory,
        schema: BuiltInPhoneToolSchema,
        permissionRequirement: PermissionRequirement,
        availabilityStatus: BuiltInPhoneToolAvailabilityStatus,
        riskTier: ActionRiskTier,
        confirmationPolicy: BuiltInPhoneToolConfirmationPolicy,
        executionKind: BuiltInPhoneToolExecutionKind,
        lifecycle: BuiltInPhoneToolLifecycleBinding,
        audit: BuiltInPhoneToolAuditMetadata,
        fallback: BuiltInPhoneToolFallback,
        sourceBinding: BuiltInPhoneToolSourceBinding = BuiltInPhoneToolSourceBinding()
    ) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.schema = schema
        self.permissionRequirement = permissionRequirement
        self.availabilityStatus = availabilityStatus
        self.riskTier = riskTier
        self.confirmationPolicy = confirmationPolicy
        self.executionKind = executionKind
        self.lifecycle = lifecycle
        self.audit = audit
        self.fallback = fallback
        self.sourceBinding = sourceBinding
    }

    public var requiresConfirmation: Bool {
        riskTier.requiresConfirmation || !confirmationPolicy.allowsExecutionWithoutConfirmation
    }

    public var canBeSuggestedAsExecutable: Bool {
        availabilityStatus.allowsExecutableSuggestion && executionKind != .setupStatusOnly
    }
}

public struct BuiltInPhoneToolCatalog: BuiltInPhoneToolCatalogProviding {
    public var tools: [BuiltInPhoneToolDefinition]

    public init(tools: [BuiltInPhoneToolDefinition] = BuiltInPhoneToolCatalog.defaultTools) {
        self.tools = tools
    }

    public func tool(id: BuiltInPhoneToolID) -> BuiltInPhoneToolDefinition? {
        tools.first { $0.id == id }
    }

    public var executableSuggestionTools: [BuiltInPhoneToolDefinition] {
        tools.filter(\.canBeSuggestedAsExecutable)
    }

    public static let defaultTools: [BuiltInPhoneToolDefinition] = [
        BuiltInPhoneToolDefinition(
            id: .memorySave,
            displayName: KairoL10n.string("chat.action.displayName.saveMemory"),
            category: .memory,
            schema: BuiltInPhoneToolSchema(input: "MemoryRecordDraft", output: "MemoryRecord"),
            permissionRequirement: .none,
            availabilityStatus: .available,
            riskTier: .tier2LowRiskWrite,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .confirmedWrite,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ActionPreviewView.memory", executor: "SandboxActionExecutor.saveMemory"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.memory]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Memory store unavailable.", safeAlternative: "Keep the content in chat without saving it."),
            sourceBinding: BuiltInPhoneToolSourceBinding(agentActionKinds: [.saveMemory], shortcutNodeKinds: [.saveMemory], recipeStepKinds: [.saveMemory])
        ),
        BuiltInPhoneToolDefinition(
            id: .memorySearch,
            displayName: KairoL10n.string("memory.search.section"),
            category: .memory,
            schema: BuiltInPhoneToolSchema(input: "MemorySearchQuery", output: "MemorySearchResults"),
            permissionRequirement: .none,
            availabilityStatus: .available,
            riskTier: .tier0ReadOnly,
            confirmationPolicy: .notRequired,
            executionKind: .readOnly,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "MemoryCenterView.searchPreview", executor: "KairoMemoryBackendService.search"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.memory]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Memory store unavailable.", safeAlternative: "Answer without saved memory context."),
            sourceBinding: BuiltInPhoneToolSourceBinding(shortcutNodeKinds: [.searchMemory], recipeStepKinds: [.searchMemory])
        ),
        BuiltInPhoneToolDefinition(
            id: .memoryDelete,
            displayName: KairoL10n.string("memory.delete.accessibility"),
            category: .memory,
            schema: BuiltInPhoneToolSchema(input: "MemoryDeleteRequest", output: "MemoryDeleteResult"),
            permissionRequirement: .none,
            availabilityStatus: .available,
            riskTier: .tier2LowRiskWrite,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .confirmedWrite,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "MemoryCenterView.deletePreview", executor: "KairoMemoryBackendService.delete"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.memory]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Memory store unavailable.", safeAlternative: "Leave memory unchanged.")
        ),
        BuiltInPhoneToolDefinition(
            id: .memoryExport,
            displayName: KairoL10n.string("memory.export.accessibility"),
            category: .memory,
            schema: BuiltInPhoneToolSchema(input: "MemoryExportRequest", output: "MemoryExportFile"),
            permissionRequirement: .userInitiated,
            availabilityStatus: .available,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewRequired,
            executionKind: .draftOnly,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "MemoryCenterView.exportPreview", executor: "KairoMemoryBackendService.export"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.memory]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Memory export unavailable.", safeAlternative: "Show memory records in Memory Center.")
        ),
        BuiltInPhoneToolDefinition(
            id: .shareImport,
            displayName: KairoL10n.string("capability.shareExtension.title"),
            category: .share,
            schema: BuiltInPhoneToolSchema(input: "ShareExtensionPayload", output: "PendingSharedContent"),
            permissionRequirement: .userInitiated,
            availabilityStatus: .available,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewRequired,
            executionKind: .draftOnly,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ShareImportBanner", executor: "ShareIngestionQueue.enqueue"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.shareExtension]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Share queue unavailable.", safeAlternative: "Copy the content into Chat manually."),
            sourceBinding: BuiltInPhoneToolSourceBinding(shortcutNodeKinds: [.summarize, .extractTasks])
        ),
        BuiltInPhoneToolDefinition(
            id: .reminderWrite,
            displayName: KairoL10n.string("chat.action.displayName.createReminder"),
            category: .reminders,
            schema: BuiltInPhoneToolSchema(input: "ReminderDraft", output: "ConfirmedReminderResult"),
            permissionRequirement: .runtimePrompt,
            availabilityStatus: .permissionRequired,
            riskTier: .tier2LowRiskWrite,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .confirmedWrite,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ActionPreviewView.reminder", executor: "SandboxActionExecutor.createReminder"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.reminders]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Reminders permission denied or EventKit unavailable.", safeAlternative: "Show a reminder draft for manual copy."),
            sourceBinding: BuiltInPhoneToolSourceBinding(agentActionKinds: [.createReminderDraft], shortcutNodeKinds: [.createReminderDraft], recipeStepKinds: [.createReminderDraft])
        ),
        BuiltInPhoneToolDefinition(
            id: .calendarWrite,
            displayName: KairoL10n.string("chat.action.displayName.createCalendar"),
            category: .calendar,
            schema: BuiltInPhoneToolSchema(input: "CalendarEventDraft", output: "ConfirmedCalendarEventResult"),
            permissionRequirement: .runtimePrompt,
            availabilityStatus: .permissionRequired,
            riskTier: .tier2LowRiskWrite,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .confirmedWrite,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ActionPreviewView.calendar", executor: "SandboxActionExecutor.createCalendarEvent"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.calendar]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Calendar permission denied or EventKit unavailable.", safeAlternative: "Show a calendar draft for manual copy."),
            sourceBinding: BuiltInPhoneToolSourceBinding(agentActionKinds: [.createCalendarDraft], shortcutNodeKinds: [.createCalendarDraft], recipeStepKinds: [.createCalendarDraft])
        ),
        BuiltInPhoneToolDefinition(
            id: .notificationSchedule,
            displayName: KairoL10n.string("chat.action.displayName.sendNotification"),
            category: .notifications,
            schema: BuiltInPhoneToolSchema(input: "NotificationDraft", output: "ScheduledNotificationResult"),
            permissionRequirement: .runtimePrompt,
            availabilityStatus: .permissionRequired,
            riskTier: .tier2LowRiskWrite,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .confirmedWrite,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ActionPreviewView.notification", executor: "SandboxActionExecutor.scheduleNotification"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.notifications]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Notification permission denied.", safeAlternative: "Show the notification draft without scheduling."),
            sourceBinding: BuiltInPhoneToolSourceBinding(agentActionKinds: [.sendNotification], recipeStepKinds: [.sendLocalNotificationDraft])
        ),
        BuiltInPhoneToolDefinition(
            id: .contactCreate,
            displayName: KairoL10n.string("chat.action.displayName.createContact"),
            category: .contacts,
            schema: BuiltInPhoneToolSchema(input: "ContactDraft", output: "ConfirmedContactResult"),
            permissionRequirement: .runtimePrompt,
            availabilityStatus: .permissionRequired,
            riskTier: .tier2LowRiskWrite,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .confirmedWrite,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ActionPreviewView.contact", executor: "SandboxActionExecutor.createContact"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.contacts]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Contacts permission denied.", safeAlternative: "Show a contact draft for manual entry."),
            sourceBinding: BuiltInPhoneToolSourceBinding(agentActionKinds: [.createContactDraft], shortcutNodeKinds: [.createContactDraft])
        ),
        BuiltInPhoneToolDefinition(
            id: .emailHandoff,
            displayName: KairoL10n.string("chat.action.displayName.composeEmail"),
            category: .handoff,
            schema: BuiltInPhoneToolSchema(input: "EmailDraft", output: "VisibleMailtoHandoff"),
            permissionRequirement: .userInitiated,
            availabilityStatus: .available,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .visibleHandoff,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ActionPreviewView.email", executor: "SandboxActionExecutor.openMailtoURL"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.mail]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Mail handoff URL could not be opened.", safeAlternative: "Show the email draft for manual copy."),
            sourceBinding: BuiltInPhoneToolSourceBinding(agentActionKinds: [.composeEmailDraft], shortcutNodeKinds: [.createEmailDraft, .draftReply])
        ),
        BuiltInPhoneToolDefinition(
            id: .messageHandoff,
            displayName: KairoL10n.string("chat.action.displayName.openMessages"),
            category: .handoff,
            schema: BuiltInPhoneToolSchema(input: "MessageDraft", output: "VisibleSMSHandoff"),
            permissionRequirement: .userInitiated,
            availabilityStatus: .available,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .visibleHandoff,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ActionPreviewView.message", executor: "SandboxActionExecutor.openSMSURL"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.messages]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Messages handoff URL could not be opened.", safeAlternative: "Show the message draft for manual copy."),
            sourceBinding: BuiltInPhoneToolSourceBinding(agentActionKinds: [.openMessageHandoff], shortcutNodeKinds: [.prepareMessageHandoff])
        ),
        BuiltInPhoneToolDefinition(
            id: .phoneHandoff,
            displayName: KairoL10n.string("chat.action.displayName.openPhone"),
            category: .handoff,
            schema: BuiltInPhoneToolSchema(input: "PhoneCallDraft", output: "VisibleTelHandoff"),
            permissionRequirement: .userInitiated,
            availabilityStatus: .available,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .visibleHandoff,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ActionPreviewView.phone", executor: "SandboxActionExecutor.openTelURL"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.phone]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Phone handoff URL could not be opened.", safeAlternative: "Show the phone number for manual dialing."),
            sourceBinding: BuiltInPhoneToolSourceBinding(agentActionKinds: [.openPhoneCallHandoff], shortcutNodeKinds: [.preparePhoneCallHandoff])
        ),
        BuiltInPhoneToolDefinition(
            id: .webSearchHandoff,
            displayName: KairoL10n.string("chat.action.displayName.openWeb"),
            category: .handoff,
            schema: BuiltInPhoneToolSchema(input: "WebSearchDraft", output: "VisibleHTTPSHandoff"),
            permissionRequirement: .userInitiated,
            availabilityStatus: .available,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .visibleHandoff,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ActionPreviewView.webSearch", executor: "SandboxActionExecutor.openHTTPSURL"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.web]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Web handoff URL could not be opened.", safeAlternative: "Show the search URL for manual opening."),
            sourceBinding: BuiltInPhoneToolSourceBinding(agentActionKinds: [.openWebSearchHandoff], shortcutNodeKinds: [.prepareWebSearchHandoff])
        ),
        BuiltInPhoneToolDefinition(
            id: .mapsDirectionsHandoff,
            displayName: KairoL10n.string("chat.action.displayName.openMaps"),
            category: .handoff,
            schema: BuiltInPhoneToolSchema(input: "MapDirectionsDraft", output: "VisibleMapsHandoff"),
            permissionRequirement: .userInitiated,
            availabilityStatus: .available,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .visibleHandoff,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ActionPreviewView.maps", executor: "SandboxActionExecutor.openMapsURL"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.location]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Maps handoff URL could not be opened.", safeAlternative: "Show the destination query for manual navigation."),
            sourceBinding: BuiltInPhoneToolSourceBinding(agentActionKinds: [.openMapDirections])
        ),
        BuiltInPhoneToolDefinition(
            id: .recipeRun,
            displayName: KairoL10n.string("automations.recipe.run"),
            category: .recipe,
            schema: BuiltInPhoneToolSchema(input: "KairoRecipeRunRequest", output: "KairoRecipeRunPreviewOrResult"),
            permissionRequirement: .userInitiated,
            availabilityStatus: .available,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewRequired,
            executionKind: .draftOnly,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "AutomationsView.recipePreview", executor: "KairoRecipeRunner.runPreviewFirst"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.appIntents]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Recipe runner unavailable.", safeAlternative: "Show recipe steps without running them."),
            sourceBinding: BuiltInPhoneToolSourceBinding(shortcutNodeKinds: [.dailyBriefing, .createRecipeDraft], recipeStepKinds: [.askKairo, .summarizeText, .extractTasks, .enqueueActionDraft, .noOp])
        ),
        BuiltInPhoneToolDefinition(
            id: .shortcutNodeInvocation,
            displayName: KairoL10n.string("root.section.shortcuts.title"),
            category: .shortcuts,
            schema: BuiltInPhoneToolSchema(input: "ShortcutNodeInput", output: "ShortcutNodeOutput"),
            permissionRequirement: .userInitiated,
            availabilityStatus: .available,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewRequired,
            executionKind: .draftOnly,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "SettingsShortcutDemosSection.preview", executor: "ShortcutNodeInvocationService.invoke"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.appIntents]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Shortcut node runtime unavailable.", safeAlternative: "Show node input/output schema only."),
            sourceBinding: BuiltInPhoneToolSourceBinding(shortcutNodeKinds: [.ask])
        ),
        BuiltInPhoneToolDefinition(
            id: .oauthConnectorSetupStatus,
            displayName: KairoL10n.string("capability.externalConnectors.title"),
            category: .integrations,
            schema: BuiltInPhoneToolSchema(input: "OAuthConnectorSetupRequest", output: "OAuthConnectorStatus"),
            permissionRequirement: .oauth,
            availabilityStatus: .setupRequired,
            riskTier: .tier0ReadOnly,
            confirmationPolicy: .manualSetupOnly,
            executionKind: .setupStatusOnly,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "SettingsOAuthConnectorsSection.status", executor: "OAuthConnectorLoginCenter.statusOnly"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.externalConnectors]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "OAuth connector is not configured.", safeAlternative: "Open Settings to connect an account."),
            sourceBinding: BuiltInPhoneToolSourceBinding(skillKinds: [.oauthConnector])
        ),
        BuiltInPhoneToolDefinition(
            id: .localModelManage,
            displayName: KairoL10n.string("settings.models.section"),
            category: .localModels,
            schema: BuiltInPhoneToolSchema(input: "LocalModelManagementRequest", output: "LocalModelSettingsStatus"),
            permissionRequirement: .userInitiated,
            availabilityStatus: .setupRequired,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewRequired,
            executionKind: .draftOnly,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "LocalModelsCompactView", executor: "LocalModelSettingsService.catalogDownloadSelectDelete"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.chat]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Local model service unavailable.", safeAlternative: "Use cloud route or local-only unavailable copy."),
            sourceBinding: BuiltInPhoneToolSourceBinding(skillKinds: [.localModel])
        ),
        BuiltInPhoneToolDefinition(
            id: .homeKitPreview,
            displayName: KairoL10n.string("chat.action.displayName.controlHome"),
            category: .home,
            schema: BuiltInPhoneToolSchema(input: "HomeControlRequest", output: "HomeControlPreview"),
            permissionRequirement: .runtimePrompt,
            availabilityStatus: .scaffolded,
            riskTier: .tier3HighRiskExternal,
            confirmationPolicy: .previewAndExplicitConfirmation,
            executionKind: .scaffoldPreviewOnly,
            lifecycle: BuiltInPhoneToolLifecycleBinding(previewRenderer: "ActionPreviewView.homeControl", executor: "SandboxActionExecutor.homeKitPreviewOnly"),
            audit: BuiltInPhoneToolAuditMetadata(capabilityKeys: [.homeKit]),
            fallback: BuiltInPhoneToolFallback(unsupportedReason: "Real HomeKit entitlement/control is not enabled.", safeAlternative: "Show a preview-only HomeKit scaffold."),
            sourceBinding: BuiltInPhoneToolSourceBinding(agentActionKinds: [.controlHome], shortcutNodeKinds: [.previewHomeAction], recipeStepKinds: [.readHomeState, .proposeHomeAction], skillKinds: [.homeKitControl])
        )
    ]
}
