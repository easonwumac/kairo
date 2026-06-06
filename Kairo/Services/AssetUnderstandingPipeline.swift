import Foundation

public protocol AssetUnderstandingModel: Sendable {
    func complete(prompt: String) async throws -> String
}

public struct AssetUnderstandingRequest: Sendable {
    public var assets: [KnowledgeAsset]
    public var folders: [KnowledgeAssetFolder]
    public var now: Date
    public var minimumConfidence: Double
    public var maximumAttempts: Int

    public init(
        assets: [KnowledgeAsset],
        folders: [KnowledgeAssetFolder] = [],
        now: Date = Date(),
        minimumConfidence: Double = 0.72,
        maximumAttempts: Int = 3
    ) {
        self.assets = assets
        self.folders = folders
        self.now = now
        self.minimumConfidence = minimumConfidence
        self.maximumAttempts = max(1, maximumAttempts)
    }
}

public struct AssetUnderstandingResult: Equatable, Sendable {
    public var draft: InfoPageDraft
    public var status: AssetUnderstandingStatus
    public var attempts: Int
    public var validationIssues: [InfoPageDraftValidationIssue]

    public var shouldAutoCreateInfoPage: Bool {
        status == .validated && draft.createInfoPage
    }
}

public enum AssetUnderstandingStatus: String, Codable, Equatable, Sendable {
    case validated
    case needsReview
}

public struct InfoPageDraft: Codable, Equatable, Sendable {
    public var createInfoPage: Bool
    public var title: String
    public var templateID: InfoPageTemplateID
    public var category: InfoPageCategory
    public var summary: String
    public var facts: [InfoPageDraftFact]
    public var timeline: [InfoPageDraftTimelineItem]
    public var reminderDrafts: [InfoPageDraftReminder]
    public var folderName: String?
    public var confidence: Double
    public var missingInfo: [String]
    public var sourceAssetIDs: [UUID]

    public init(
        createInfoPage: Bool,
        title: String,
        templateID: InfoPageTemplateID,
        category: InfoPageCategory,
        summary: String,
        facts: [InfoPageDraftFact] = [],
        timeline: [InfoPageDraftTimelineItem] = [],
        reminderDrafts: [InfoPageDraftReminder] = [],
        folderName: String? = nil,
        confidence: Double,
        missingInfo: [String] = [],
        sourceAssetIDs: [UUID] = []
    ) {
        self.createInfoPage = createInfoPage
        self.title = title
        self.templateID = templateID
        self.category = category
        self.summary = summary
        self.facts = facts
        self.timeline = timeline
        self.reminderDrafts = reminderDrafts
        self.folderName = folderName
        self.confidence = confidence
        self.missingInfo = missingInfo
        self.sourceAssetIDs = sourceAssetIDs
    }

    public func makeInfoPage(now: Date = Date()) -> InfoPage {
        let pageID = UUID()
        let reminders = reminderDrafts.map { draft in
            ReminderLink.draft(infoPageID: pageID, title: draft.title)
        }
        let actions = reminders.map { reminder in
            AgentAction(
                kind: .createReminderDraft,
                title: KairoL10n.string("actionInbox.action.createReminder"),
                rationale: "Created from validated asset understanding draft.",
                payload: .reminder(ReminderDraft(title: reminder.title, notes: reminder.notesFallback, dueDate: reminder.dueDate)),
                riskTier: .tier2LowRiskWrite
            )
        }
        return InfoPage(
            id: pageID,
            title: title,
            category: category,
            templateID: templateID,
            summary: summary,
            facts: facts.map { InfoPageFact(label: $0.label, value: $0.value, sourceAssetID: $0.sourceAssetID) },
            timeline: timeline.map { InfoPageTimelineItem(title: $0.title, note: $0.note, sourceAssetID: $0.sourceAssetID) },
            assetIDs: sourceAssetIDs,
            reminderLinks: reminders,
            actionDrafts: actions,
            createdAt: now,
            updatedAt: now
        )
    }
}

public struct InfoPageDraftFact: Codable, Equatable, Sendable {
    public var label: String
    public var value: String
    public var sourceAssetID: UUID?

    public init(label: String, value: String, sourceAssetID: UUID? = nil) {
        self.label = label
        self.value = value
        self.sourceAssetID = sourceAssetID
    }
}

public struct InfoPageDraftTimelineItem: Codable, Equatable, Sendable {
    public var title: String
    public var note: String?
    public var sourceAssetID: UUID?

    public init(title: String, note: String? = nil, sourceAssetID: UUID? = nil) {
        self.title = title
        self.note = note
        self.sourceAssetID = sourceAssetID
    }
}

public struct InfoPageDraftReminder: Codable, Equatable, Sendable {
    public var title: String
    public var dueDateText: String?
    public var needsUserConfirmation: Bool

    public init(title: String, dueDateText: String? = nil, needsUserConfirmation: Bool = true) {
        self.title = title
        self.dueDateText = dueDateText
        self.needsUserConfirmation = needsUserConfirmation
    }
}

public enum InfoPageDraftValidationIssue: Equatable, Sendable, CustomStringConvertible {
    case invalidJSON
    case emptyTitle
    case emptySummary
    case mismatchedCategory(template: InfoPageTemplateID, category: InfoPageCategory, expected: InfoPageCategory)
    case missingRequiredFact(String)
    case confidenceTooLow(Double)
    case unknownFolder(String)
    case unsafeGeneratedMarkup
    case missingSourceAsset
    case reminderWithoutConfirmation(String)

    public var description: String {
        switch self {
        case .invalidJSON:
            return "Output must be one valid JSON object."
        case .emptyTitle:
            return "title is required."
        case .emptySummary:
            return "summary is required."
        case .mismatchedCategory(let template, let category, let expected):
            return "category \(category.rawValue) does not match templateID \(template.rawValue); expected \(expected.rawValue)."
        case .missingRequiredFact(let key):
            return "facts must include required key \(key)."
        case .confidenceTooLow(let confidence):
            return "confidence \(confidence) is below the minimum threshold."
        case .unknownFolder(let folder):
            return "folderName \(folder) is not in the provided folder list."
        case .unsafeGeneratedMarkup:
            return "Do not output HTML, Markdown fences, script, or template source."
        case .missingSourceAsset:
            return "sourceAssetIDs must reference at least one imported asset."
        case .reminderWithoutConfirmation(let title):
            return "reminderDraft \(title) must set needsUserConfirmation=true."
        }
    }
}

public enum InfoPageDraftValidator {
    public static func validate(
        _ draft: InfoPageDraft,
        sourceAssetIDs: Set<UUID>,
        folders: [KnowledgeAssetFolder],
        minimumConfidence: Double
    ) -> [InfoPageDraftValidationIssue] {
        var issues: [InfoPageDraftValidationIssue] = []
        let definition = InfoPageTemplateCatalog.definition(for: draft.templateID)
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.emptyTitle)
        }
        if draft.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.emptySummary)
        }
        if draft.category != definition.category {
            issues.append(.mismatchedCategory(template: draft.templateID, category: draft.category, expected: definition.category))
        }
        let factLabels = Set(draft.facts.map { $0.label })
        for requiredKey in definition.requiredFactKeys where !factLabels.contains(requiredKey) {
            issues.append(.missingRequiredFact(requiredKey))
        }
        if draft.confidence < minimumConfidence {
            issues.append(.confidenceTooLow(draft.confidence))
        }
        if let folderName = draft.folderName,
           !folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !folders.contains(where: { $0.name.localizedCaseInsensitiveCompare(folderName) == .orderedSame }) {
            issues.append(.unknownFolder(folderName))
        }
        if containsUnsafeGeneratedMarkup(draft) {
            issues.append(.unsafeGeneratedMarkup)
        }
        if draft.sourceAssetIDs.isEmpty || draft.sourceAssetIDs.contains(where: { !sourceAssetIDs.contains($0) }) {
            issues.append(.missingSourceAsset)
        }
        for reminder in draft.reminderDrafts where !reminder.needsUserConfirmation {
            issues.append(.reminderWithoutConfirmation(reminder.title))
        }
        return issues
    }

    private static func containsUnsafeGeneratedMarkup(_ draft: InfoPageDraft) -> Bool {
        let text = ([draft.title, draft.summary, draft.folderName ?? ""] +
            draft.facts.flatMap { [$0.label, $0.value] } +
            draft.timeline.flatMap { [$0.title, $0.note ?? ""] } +
            draft.reminderDrafts.map(\.title))
            .joined(separator: "\n")
            .lowercased()
        return ["<html", "<script", "```", "<body", "<!doctype"].contains { text.contains($0) }
    }
}

public struct AssetUnderstandingPipeline: Sendable {
    private let model: any AssetUnderstandingModel

    public init(model: any AssetUnderstandingModel) {
        self.model = model
    }

    public func understand(_ request: AssetUnderstandingRequest) async -> AssetUnderstandingResult {
        var issues: [InfoPageDraftValidationIssue] = [.invalidJSON]
        var attempts = 0
        for attempt in 1...request.maximumAttempts {
            attempts = attempt
            let prompt = attempt == 1
                ? Self.initialPrompt(for: request)
                : Self.repairPrompt(for: request, issues: issues)
            do {
                let raw = try await model.complete(prompt: prompt)
                guard let draft = Self.decodeDraft(from: raw) else {
                    issues = [.invalidJSON]
                    continue
                }
                let normalized = Self.normalizedDraft(draft, request: request)
                issues = InfoPageDraftValidator.validate(
                    normalized,
                    sourceAssetIDs: Set(request.assets.map(\.id)),
                    folders: request.folders,
                    minimumConfidence: request.minimumConfidence
                )
                if issues.isEmpty {
                    return AssetUnderstandingResult(
                        draft: normalized,
                        status: .validated,
                        attempts: attempts,
                        validationIssues: []
                    )
                }
            } catch {
                issues = [.invalidJSON]
            }
        }
        return AssetUnderstandingResult(
            draft: Self.fallbackDraft(for: request, issues: issues),
            status: .needsReview,
            attempts: attempts,
            validationIssues: issues
        )
    }

    public static func initialPrompt(for request: AssetUnderstandingRequest) -> String {
        """
        You are classifying imported iPhone assets for Kairo Library.
        Use only the provided OCR, labels, file metadata, and user text.
        Output one JSON object only. No Markdown. No HTML. No comments.
        The App renders fixed HTML templates from this JSON; never generate template source.
        Every reminderDraft must set needsUserConfirmation=true.
        Use a folderName only if it exactly matches one provided folder.
        Minimum confidence for automatic InfoPage creation: \(request.minimumConfidence).

        Schema:
        {"createInfoPage":true,"title":"short title","templateID":"travel|order|warranty|project|event|medical|finance|identityDocument|homeDevice|subscription|recipeOrInstruction|generalNote","category":"same category required by template","summary":"one sentence","facts":[{"label":"required or optional key","value":"source-backed value","sourceAssetID":"uuid"}],"timeline":[{"title":"event","note":"source-backed note","sourceAssetID":"uuid"}],"reminderDrafts":[{"title":"draft title","dueDateText":"optional natural date","needsUserConfirmation":true}],"folderName":"optional exact folder name","confidence":0.0,"missingInfo":["unknown but useful fields"],"sourceAssetIDs":["uuid"]}

        Templates:
        \(templateSchemaLines())

        Folders:
        \(request.folders.map(\.name).joined(separator: ", "))

        Assets:
        \(assetLines(request.assets))
        """
    }

    public static func repairPrompt(for request: AssetUnderstandingRequest, issues: [InfoPageDraftValidationIssue]) -> String {
        """
        Repair the previous Kairo Library JSON. Return one valid JSON object only.
        Do not reinterpret beyond provided assets. Fix these validation errors:
        \(issues.map(\.description).joined(separator: "\n"))

        \(initialPrompt(for: request))
        """
    }

    private static func decodeDraft(from raw: String) -> InfoPageDraft? {
        guard let json = extractJSONObject(from: raw),
              let data = json.data(using: .utf8)
        else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(InfoPageDraft.self, from: data)
    }

    private static func extractJSONObject(from raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"),
              start <= end
        else { return nil }
        return String(raw[start...end])
    }

    private static func normalizedDraft(_ draft: InfoPageDraft, request: AssetUnderstandingRequest) -> InfoPageDraft {
        var normalized = draft
        if normalized.sourceAssetIDs.isEmpty {
            normalized.sourceAssetIDs = request.assets.map(\.id)
        }
        return normalized
    }

    private static func fallbackDraft(
        for request: AssetUnderstandingRequest,
        issues: [InfoPageDraftValidationIssue]
    ) -> InfoPageDraft {
        let page = InfoPageGenerator.generate(from: InfoPageGenerationInput(
            assets: request.assets,
            preferredTemplateID: .generalNote,
            now: request.now
        ))
        return InfoPageDraft(
            createInfoPage: false,
            title: page.title,
            templateID: page.templateID,
            category: page.category,
            summary: page.summary.isEmpty ? "Needs manual review before saving." : page.summary,
            facts: page.facts.map { InfoPageDraftFact(label: $0.label, value: $0.value, sourceAssetID: $0.sourceAssetID) },
            timeline: page.timeline.map { InfoPageDraftTimelineItem(title: $0.title, note: $0.note, sourceAssetID: $0.sourceAssetID) },
            reminderDrafts: [],
            folderName: nil,
            confidence: 0,
            missingInfo: issues.map(\.description),
            sourceAssetIDs: request.assets.map(\.id)
        )
    }

    private static func templateSchemaLines() -> String {
        InfoPageTemplateCatalog.all.map { definition in
            """
            \(definition.id.rawValue): category=\(definition.category.rawValue), required=\(definition.requiredFactKeys.joined(separator: ",")), optional=\(definition.optionalFactKeys.joined(separator: ","))
            """
        }.joined(separator: "\n")
    }

    private static func assetLines(_ assets: [KnowledgeAsset]) -> String {
        assets.map { asset in
            """
            id=\(asset.id.uuidString)
            title=\(asset.title)
            kind=\(asset.kind.rawValue)
            text=\(truncate([asset.extractedText, asset.generatedDescription ?? "", asset.summary].joined(separator: "\n"), limit: 900))
            tags=\(asset.tags.joined(separator: ","))
            attachments=\(asset.attachments.map(\.displayName).joined(separator: ","))
            """
        }.joined(separator: "\n---\n")
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit))
    }
}
