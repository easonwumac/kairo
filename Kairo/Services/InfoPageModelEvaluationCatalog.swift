import Foundation

public struct InfoPageModelEvaluationCandidate: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var recommendedRole: InfoPageModelRole
    public var expectedTemplateCoverage: [InfoPageTemplateID]
    public var minimumAcceptedScore: Double
    public var requiresVisionInput: Bool
    public var downloadableModelID: String?
    public var notes: String

    public init(
        id: String,
        displayName: String,
        recommendedRole: InfoPageModelRole,
        expectedTemplateCoverage: [InfoPageTemplateID],
        minimumAcceptedScore: Double,
        requiresVisionInput: Bool,
        downloadableModelID: String? = nil,
        notes: String
    ) {
        self.id = id
        self.displayName = displayName
        self.recommendedRole = recommendedRole
        self.expectedTemplateCoverage = expectedTemplateCoverage
        self.minimumAcceptedScore = minimumAcceptedScore
        self.requiresVisionInput = requiresVisionInput
        self.downloadableModelID = downloadableModelID
        self.notes = notes
    }
}

public enum InfoPageModelRole: String, Codable, CaseIterable, Sendable {
    case fallbackTextExtraction
    case minimumVisionExtraction
    case preferredOnDeviceExtraction
}

public struct InfoPageModelEvaluationCase: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var templateID: InfoPageTemplateID
    public var sourceDescription: String
    public var requiredFactKeys: [String]
    public var requiredReminderKeys: [String]

    public init(
        id: String,
        templateID: InfoPageTemplateID,
        sourceDescription: String,
        requiredFactKeys: [String],
        requiredReminderKeys: [String]
    ) {
        self.id = id
        self.templateID = templateID
        self.sourceDescription = sourceDescription
        self.requiredFactKeys = requiredFactKeys
        self.requiredReminderKeys = requiredReminderKeys
    }
}

public enum InfoPageModelEvaluationCatalog {
    public static let candidates: [InfoPageModelEvaluationCandidate] = [
        InfoPageModelEvaluationCandidate(
            id: "qwen3-5-0-8b-q4-k-m",
            displayName: "Qwen3.5 0.8B Q4_K_M",
            recommendedRole: .fallbackTextExtraction,
            expectedTemplateCoverage: [.generalNote, .project, .order],
            minimumAcceptedScore: 0.68,
            requiresVisionInput: false,
            downloadableModelID: LocalModelManifest.qwen35Tiny.id,
            notes: "Lowest fallback for OCR text cleanup and simple extraction. Not acceptable as the primary screenshot understanding model."
        ),
        InfoPageModelEvaluationCandidate(
            id: "gemma-4-e2b-it",
            displayName: "Gemma 4 E2B IT",
            recommendedRole: .minimumVisionExtraction,
            expectedTemplateCoverage: [.travel, .order, .warranty, .event, .homeDevice, .subscription, .generalNote],
            minimumAcceptedScore: 0.78,
            requiresVisionInput: true,
            downloadableModelID: nil,
            notes: "Minimum candidate for on-device image-to-structured-info extraction once a signed iOS-compatible artifact is available."
        ),
        InfoPageModelEvaluationCandidate(
            id: "gemma-4-e4b-it",
            displayName: "Gemma 4 E4B IT",
            recommendedRole: .preferredOnDeviceExtraction,
            expectedTemplateCoverage: InfoPageTemplateID.allCases,
            minimumAcceptedScore: 0.84,
            requiresVisionInput: true,
            downloadableModelID: nil,
            notes: "Preferred local candidate for multi-asset InfoPage generation, especially travel, project, and high-ambiguity screenshots."
        )
    ]

    public static let evaluationCases: [InfoPageModelEvaluationCase] = [
        .init(
            id: "travel-hong-kong-pickup",
            templateID: .travel,
            sourceDescription: "Airport pickup screenshot for Hong Kong travel with outbound booking but missing return trip.",
            requiredFactKeys: ["destination", "bookingStatus", "pickup", "returnTrip"],
            requiredReminderKeys: ["confirmReturnTrip", "checkTravelDocuments"]
        ),
        .init(
            id: "order-delivery-return",
            templateID: .order,
            sourceDescription: "Order confirmation screenshot with merchant, order number, delivery status, and return deadline.",
            requiredFactKeys: ["merchant", "orderStatus", "orderNumber"],
            requiredReminderKeys: ["trackDelivery", "returnDeadline"]
        ),
        .init(
            id: "project-next-step",
            templateID: .project,
            sourceDescription: "Project notes with goal, deadline, test gap, and next action.",
            requiredFactKeys: ["goal", "nextStep"],
            requiredReminderKeys: ["nextStep", "deadline"]
        )
    ]

    public static var minimumPrimaryCandidate: InfoPageModelEvaluationCandidate {
        candidates.first { $0.id == "gemma-4-e2b-it" }!
    }

    public static var preferredCandidate: InfoPageModelEvaluationCandidate {
        candidates.first { $0.id == "gemma-4-e4b-it" }!
    }
}
