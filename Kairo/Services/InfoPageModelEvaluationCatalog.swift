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
            id: "qwen2-5-0-5b-instruct-q4-k-m",
            displayName: "Qwen2.5 0.5B Instruct Q4_K_M",
            recommendedRole: .fallbackTextExtraction,
            expectedTemplateCoverage: [.generalNote, .project, .order],
            minimumAcceptedScore: 0.68,
            requiresVisionInput: false,
            downloadableModelID: LocalModelManifest.qwen25HalfBInstruct.id,
            notes: "Lowest instruct fallback for OCR text cleanup and simple extraction. Not acceptable as the primary screenshot understanding model."
        ),
        InfoPageModelEvaluationCandidate(
            id: "qwen2-5-1-5b-instruct-q4-k-m",
            displayName: "Qwen2.5 1.5B Instruct Q4_K_M",
            recommendedRole: .fallbackTextExtraction,
            expectedTemplateCoverage: [.generalNote, .project, .order, .travel],
            minimumAcceptedScore: 0.72,
            requiresVisionInput: false,
            downloadableModelID: LocalModelManifest.qwen25OneAndHalfBInstruct.id,
            notes: "Required text fallback for Apple Vision OCR output and Library asset extraction when a direct vision model is unavailable."
        ),
        InfoPageModelEvaluationCandidate(
            id: "qwen2-5-vl-3b-instruct-q4-k-m",
            displayName: "Qwen2.5-VL 3B Instruct Q4_K_M",
            recommendedRole: .minimumVisionExtraction,
            expectedTemplateCoverage: [.travel, .order, .warranty, .event, .generalNote],
            minimumAcceptedScore: 0.76,
            requiresVisionInput: true,
            downloadableModelID: LocalModelManifest.qwen25VLThreeBInstruct.id,
            notes: "First downloadable vision-language candidate because its GGUF model and mmproj companion are both represented in the local catalog."
        ),
        InfoPageModelEvaluationCandidate(
            id: "gemma-4-e2b-it-qat-q4-0-gguf",
            displayName: "Gemma 4 E2B IT QAT Q4_0",
            recommendedRole: .minimumVisionExtraction,
            expectedTemplateCoverage: [.travel, .order, .warranty, .event, .homeDevice, .subscription, .generalNote],
            minimumAcceptedScore: 0.78,
            requiresVisionInput: true,
            downloadableModelID: LocalModelManifest.gemma4E2BQATQ4_0.id,
            notes: "Primary downloadable QAT candidate for asset understanding. Kairo still validates JSON output and uses Apple Vision references until direct iOS multimodal runtime is verified."
        ),
        InfoPageModelEvaluationCandidate(
            id: "gemma-4-e4b-it-qat-q4-0-gguf",
            displayName: "Gemma 4 E4B IT QAT Q4_0",
            recommendedRole: .preferredOnDeviceExtraction,
            expectedTemplateCoverage: InfoPageTemplateID.allCases,
            minimumAcceptedScore: 0.84,
            requiresVisionInput: true,
            downloadableModelID: LocalModelManifest.gemma4E4BQATQ4_0.id,
            notes: "Higher-quality QAT candidate for multi-asset InfoPage generation. Larger download and memory footprint keep E2B as the default recommendation."
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
        candidates.first { $0.id == LocalModelManifest.gemma4E2BQATQ4_0.id }!
    }

    public static var preferredCandidate: InfoPageModelEvaluationCandidate {
        candidates.first { $0.id == LocalModelManifest.gemma4E4BQATQ4_0.id }!
    }
}
