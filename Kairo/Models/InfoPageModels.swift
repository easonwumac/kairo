import Foundation

public struct InfoPage: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var category: InfoPageCategory
    public var templateID: InfoPageTemplateID
    public var summary: String
    public var facts: [InfoPageFact]
    public var timeline: [InfoPageTimelineItem]
    public var assetIDs: [UUID]
    public var reminderLinks: [ReminderLink]
    public var actionDrafts: [AgentAction]
    public var spaceIDs: [UUID]
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        category: InfoPageCategory,
        templateID: InfoPageTemplateID,
        summary: String = "",
        facts: [InfoPageFact] = [],
        timeline: [InfoPageTimelineItem] = [],
        assetIDs: [UUID] = [],
        reminderLinks: [ReminderLink] = [],
        actionDrafts: [AgentAction] = [],
        spaceIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.templateID = templateID
        self.summary = summary
        self.facts = facts
        self.timeline = timeline
        self.assetIDs = assetIDs
        self.reminderLinks = reminderLinks
        self.actionDrafts = actionDrafts
        self.spaceIDs = spaceIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

public enum InfoPageCategory: String, Codable, CaseIterable, Sendable {
    case travel
    case order
    case warranty
    case project
    case event
    case medical
    case finance
    case identityDocument
    case homeDevice
    case subscription
    case recipeOrInstruction
    case generalNote
}

public enum InfoPageTemplateID: String, Codable, CaseIterable, Sendable {
    case travel
    case order
    case warranty
    case project
    case event
    case medical
    case finance
    case identityDocument
    case homeDevice
    case subscription
    case recipeOrInstruction
    case generalNote
}

public struct InfoPageFact: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var label: String
    public var value: String
    public var sourceAssetID: UUID?

    public init(id: UUID = UUID(), label: String, value: String, sourceAssetID: UUID? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.sourceAssetID = sourceAssetID
    }
}

public struct InfoPageTimelineItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var date: Date?
    public var note: String?
    public var sourceAssetID: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        date: Date? = nil,
        note: String? = nil,
        sourceAssetID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.note = note
        self.sourceAssetID = sourceAssetID
    }
}

public struct ReminderLink: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var infoPageID: UUID
    public var reminderIdentifier: String?
    public var title: String
    public var dueDate: Date?
    public var deepLink: URL
    public var notesFallback: String
    public var status: ReminderLinkStatus
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        infoPageID: UUID,
        reminderIdentifier: String? = nil,
        title: String,
        dueDate: Date? = nil,
        deepLink: URL = URL(string: "kairo://info-page/00000000-0000-0000-0000-000000000000")!,
        notesFallback: String = "",
        status: ReminderLinkStatus = .draft,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.infoPageID = infoPageID
        self.reminderIdentifier = reminderIdentifier
        self.title = title
        self.dueDate = dueDate
        self.deepLink = deepLink
        self.notesFallback = notesFallback
        self.status = status
        self.createdAt = createdAt
    }

    public static func draft(infoPageID: UUID, title: String, dueDate: Date? = nil) -> ReminderLink {
        let deepLink = URL(string: "kairo://info-page/\(infoPageID.uuidString)")!
        return ReminderLink(
            infoPageID: infoPageID,
            title: title,
            dueDate: dueDate,
            deepLink: deepLink,
            notesFallback: "\(title)\n\(deepLink.absoluteString)",
            status: .draft
        )
    }
}

public enum ReminderLinkStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case confirmed
    case failed
    case cancelled
}

public struct InfoSpace: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var assetIDs: [UUID]
    public var infoPageIDs: [UUID]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        assetIDs: [UUID] = [],
        infoPageIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.assetIDs = assetIDs
        self.infoPageIDs = infoPageIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct InfoPageTemplateDefinition: Identifiable, Codable, Equatable, Sendable {
    public var id: InfoPageTemplateID
    public var category: InfoPageCategory
    public var htmlTemplateName: String
    public var requiredFactKeys: [String]
    public var optionalFactKeys: [String]
    public var timelineKeys: [String]
    public var suggestedReminderKeys: [String]
    public var minimumModelCapability: InfoPageMinimumModelCapability

    public init(
        id: InfoPageTemplateID,
        category: InfoPageCategory,
        htmlTemplateName: String,
        requiredFactKeys: [String],
        optionalFactKeys: [String],
        timelineKeys: [String],
        suggestedReminderKeys: [String],
        minimumModelCapability: InfoPageMinimumModelCapability
    ) {
        self.id = id
        self.category = category
        self.htmlTemplateName = htmlTemplateName
        self.requiredFactKeys = requiredFactKeys
        self.optionalFactKeys = optionalFactKeys
        self.timelineKeys = timelineKeys
        self.suggestedReminderKeys = suggestedReminderKeys
        self.minimumModelCapability = minimumModelCapability
    }
}

public enum InfoPageMinimumModelCapability: String, Codable, CaseIterable, Sendable {
    case textExtraction
    case visionExtraction
    case structuredReasoning
    case highSensitivityExtraction
}

public enum InfoPageTemplateCatalog {
    public static let all: [InfoPageTemplateDefinition] = [
        .init(
            id: .travel,
            category: .travel,
            htmlTemplateName: "travel",
            requiredFactKeys: ["destination", "bookingStatus"],
            optionalFactKeys: ["flight", "hotel", "pickup", "returnTrip", "passport", "visa"],
            timelineKeys: ["departure", "arrival", "hotelCheckIn", "hotelCheckOut", "pickup"],
            suggestedReminderKeys: ["confirmReturnTrip", "checkTravelDocuments", "reviewPickup"],
            minimumModelCapability: .visionExtraction
        ),
        .init(
            id: .order,
            category: .order,
            htmlTemplateName: "order",
            requiredFactKeys: ["merchant", "orderStatus"],
            optionalFactKeys: ["orderNumber", "amount", "deliveryWindow", "returnDeadline"],
            timelineKeys: ["orderedAt", "deliveryETA", "returnDeadline"],
            suggestedReminderKeys: ["trackDelivery", "returnDeadline"],
            minimumModelCapability: .textExtraction
        ),
        .init(
            id: .warranty,
            category: .warranty,
            htmlTemplateName: "warranty",
            requiredFactKeys: ["item", "proofOfPurchase"],
            optionalFactKeys: ["serialNumber", "purchaseDate", "warrantyEnd", "repairContact"],
            timelineKeys: ["purchaseDate", "warrantyEnd"],
            suggestedReminderKeys: ["warrantyExpiry"],
            minimumModelCapability: .textExtraction
        ),
        .init(
            id: .project,
            category: .project,
            htmlTemplateName: "project",
            requiredFactKeys: ["goal", "nextStep"],
            optionalFactKeys: ["deadline", "owner", "risk", "decision"],
            timelineKeys: ["deadline", "milestone"],
            suggestedReminderKeys: ["nextStep", "deadline"],
            minimumModelCapability: .structuredReasoning
        ),
        .init(
            id: .event,
            category: .event,
            htmlTemplateName: "event",
            requiredFactKeys: ["eventName", "time"],
            optionalFactKeys: ["venue", "ticket", "transport", "dressCode"],
            timelineKeys: ["start", "end", "arrival"],
            suggestedReminderKeys: ["leaveOnTime", "bringTicket"],
            minimumModelCapability: .textExtraction
        ),
        .init(
            id: .medical,
            category: .medical,
            htmlTemplateName: "medical",
            requiredFactKeys: ["medicalContext", "source"],
            optionalFactKeys: ["appointment", "medication", "doctor", "followUp"],
            timelineKeys: ["appointment", "followUp"],
            suggestedReminderKeys: ["appointment", "followUp"],
            minimumModelCapability: .highSensitivityExtraction
        ),
        .init(
            id: .finance,
            category: .finance,
            htmlTemplateName: "finance",
            requiredFactKeys: ["financialDocument", "source"],
            optionalFactKeys: ["amount", "dueDate", "account", "contract"],
            timelineKeys: ["dueDate", "renewalDate"],
            suggestedReminderKeys: ["paymentDue", "renewalReview"],
            minimumModelCapability: .highSensitivityExtraction
        ),
        .init(
            id: .identityDocument,
            category: .identityDocument,
            htmlTemplateName: "identity-document",
            requiredFactKeys: ["documentType", "holder"],
            optionalFactKeys: ["documentNumber", "expiryDate", "issuingCountry"],
            timelineKeys: ["expiryDate", "renewalWindow"],
            suggestedReminderKeys: ["renewBeforeExpiry"],
            minimumModelCapability: .highSensitivityExtraction
        ),
        .init(
            id: .homeDevice,
            category: .homeDevice,
            htmlTemplateName: "home-device",
            requiredFactKeys: ["deviceName", "model"],
            optionalFactKeys: ["serialNumber", "manual", "consumable", "warrantyEnd"],
            timelineKeys: ["purchaseDate", "maintenance", "warrantyEnd"],
            suggestedReminderKeys: ["maintenance", "warrantyExpiry"],
            minimumModelCapability: .textExtraction
        ),
        .init(
            id: .subscription,
            category: .subscription,
            htmlTemplateName: "subscription",
            requiredFactKeys: ["service", "plan"],
            optionalFactKeys: ["renewalDate", "amount", "paymentMethod", "cancelDeadline"],
            timelineKeys: ["renewalDate", "cancelDeadline"],
            suggestedReminderKeys: ["renewalReview", "cancelDeadline"],
            minimumModelCapability: .textExtraction
        ),
        .init(
            id: .recipeOrInstruction,
            category: .recipeOrInstruction,
            htmlTemplateName: "recipe-instruction",
            requiredFactKeys: ["title", "steps"],
            optionalFactKeys: ["materials", "tools", "warnings", "source"],
            timelineKeys: ["step"],
            suggestedReminderKeys: ["prepareMaterials"],
            minimumModelCapability: .structuredReasoning
        ),
        .init(
            id: .generalNote,
            category: .generalNote,
            htmlTemplateName: "general-note",
            requiredFactKeys: ["topic"],
            optionalFactKeys: ["summary", "source", "relatedPeople", "relatedPlaces"],
            timelineKeys: ["mentionedDate"],
            suggestedReminderKeys: ["review"],
            minimumModelCapability: .textExtraction
        )
    ]

    public static func definition(for id: InfoPageTemplateID) -> InfoPageTemplateDefinition {
        all.first { $0.id == id } ?? all.last!
    }
}
