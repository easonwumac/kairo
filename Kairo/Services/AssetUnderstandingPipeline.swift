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
    public var executionMode: AssetUnderstandingExecutionMode

    public init(
        assets: [KnowledgeAsset],
        folders: [KnowledgeAssetFolder] = [],
        now: Date = Date(),
        minimumConfidence: Double = 0.72,
        maximumAttempts: Int = 3,
        executionMode: AssetUnderstandingExecutionMode = .singlePrompt
    ) {
        self.assets = assets
        self.folders = folders
        self.now = now
        self.minimumConfidence = minimumConfidence
        self.maximumAttempts = max(1, maximumAttempts)
        self.executionMode = executionMode
    }
}

public enum AssetUnderstandingExecutionMode: String, Codable, Equatable, Sendable {
    case singlePrompt
    case staged
}

public struct AssetUnderstandingResult: Equatable, Sendable {
    public var draft: InfoPageDraft
    public var status: AssetUnderstandingStatus
    public var attempts: Int
    public var validationIssues: [InfoPageDraftValidationIssue]

    public var requiresCategoryChoice: Bool {
        (draft.candidateCategories?.count ?? 0) > 1
    }

    public var shouldAutoCreateInfoPage: Bool {
        status == .validated && draft.createInfoPage && !requiresCategoryChoice
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
    public var assetDescription: String?
    public var ocrSummary: String?
    public var keywords: [String]?
    public var candidateCategories: [InfoPageDraftCategoryCandidate]?

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
        sourceAssetIDs: [UUID] = [],
        assetDescription: String? = nil,
        ocrSummary: String? = nil,
        keywords: [String]? = nil,
        candidateCategories: [InfoPageDraftCategoryCandidate]? = nil
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
        self.assetDescription = assetDescription
        self.ocrSummary = ocrSummary
        self.keywords = keywords
        self.candidateCategories = candidateCategories
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

public struct InfoPageDraftCategoryCandidate: Codable, Equatable, Sendable {
    public var folderName: String?
    public var templateID: InfoPageTemplateID
    public var category: InfoPageCategory
    public var confidence: Double
    public var reason: String

    public init(
        folderName: String? = nil,
        templateID: InfoPageTemplateID,
        category: InfoPageCategory,
        confidence: Double,
        reason: String
    ) {
        self.folderName = folderName
        self.templateID = templateID
        self.category = category
        self.confidence = confidence
        self.reason = reason
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

public enum AssetUnderstandingPromptBuilder {
    public static func classifyPrompt(for request: AssetUnderstandingRequest) -> String {
        """
        Stage classifyAsset for Kairo asset understanding.
        Return one compact JSON object only:
        {"bestTemplateID":"generalNote","bestCategory":"generalNote","confidence":0.0,"candidateCategories":[{"folderName":"optional exact folder","templateID":"generalNote","category":"generalNote","confidence":0.0,"reason":"source-backed reason"}],"missingInfo":["useful missing fields"]}

        Rules:
        - Use only supplied assets and enabled folders.
        - If evidence is weak or ambiguous, prefer generalNote and include candidateCategories.
        - Do not generate final InfoPage JSON in this stage.

        Templates:
        \(templateSchemaLines())

        Enabled folders/categories:
        \(request.folders.map(\.name).joined(separator: ", "))

        Assets:
        \(assetLines(request.assets))
        """
    }

    public static func extractFactsPrompt(for request: AssetUnderstandingRequest, classification: String) -> String {
        """
        Stage extractFacts for Kairo asset understanding.
        Return one compact JSON object only:
        {"assetDescription":"plain description","ocrSummary":"source text summary","keywords":["term"],"facts":[{"label":"key","value":"source-backed value","sourceAssetID":"uuid"}],"timeline":[{"title":"event","note":"source-backed note","sourceAssetID":"uuid"}],"reminderDrafts":[{"title":"draft title","dueDateText":"optional natural date","needsUserConfirmation":true}],"missingInfo":["unknown but useful fields"]}

        Classification result:
        \(classification)

        Rules:
        - Copy only facts supported by supplied OCR, labels, URL page text, file metadata, or user text.
        - Every reminderDraft must set needsUserConfirmation=true.
        - Do not generate final InfoPage JSON in this stage.

        Assets:
        \(assetLines(request.assets))
        """
    }

    public static func composePrompt(
        for request: AssetUnderstandingRequest,
        classification: String,
        extractedFacts: String
    ) -> String {
        """
        Stage composeInfoPageJSON for Kairo asset understanding.
        Return the final fixed schema JSON object only. No Markdown. No HTML. No comments.

        Classification result:
        \(classification)

        Extracted facts result:
        \(extractedFacts)

        Final schema:
        \(schemaLine())

        Required rules:
        - category must match templateID category.
        - facts must include required keys for the chosen template when source-backed.
        - Use sourceAssetIDs only from supplied assets.
        - Every reminderDraft must set needsUserConfirmation=true.
        - Use folderName only if it exactly matches an enabled folder.
        - If multiple categories remain plausible, include candidateCategories and keep createInfoPage true only when review is safe.
        - Minimum confidence for automatic InfoPage creation: \(request.minimumConfidence).

        Templates:
        \(templateSchemaLines())

        Enabled folders/categories:
        \(request.folders.map(\.name).joined(separator: ", "))

        Assets:
        \(assetLines(request.assets))
        """
    }

    public static func initialPrompt(for request: AssetUnderstandingRequest) -> String {
        """
        You are Kairo's staged asset-understanding pipeline for imported iPhone assets.
        Use only the provided OCR, labels, file metadata, URL page text, and user text.
        Output one JSON object only. No Markdown. No HTML. No comments.
        The App renders fixed HTML templates from this JSON; never generate template source.
        Every reminderDraft must set needsUserConfirmation=true.
        Use a folderName only if it exactly matches one provided folder.
        Minimum confidence for automatic InfoPage creation: \(request.minimumConfidence).

        Pipeline stages:
        1. classifyAsset: choose the best template/category or list 2-4 candidateCategories when ambiguous.
        2. extractFacts: copy only source-backed facts, timeline items, keywords, missingInfo, and reminder drafts from the supplied assets.
        3. composeInfoPageJSON: emit the final fixed schema JSON object after classification and extraction.

        Stability rules:
        - Prefer generalNote with createInfoPage=false when evidence is weak.
        - Never invent facts, dates, folders, or sourceAssetIDs.
        - Keep values concise so small local models can stay inside schema.
        - If a URL pageText exists, summarize it as source text, not as verified browsing beyond the provided snippet.
        - If multiple enabled folders/categories are plausible, include candidateCategories and do not force a single automatic save.

        Schema:
        \(schemaLine())

        Templates:
        \(templateSchemaLines())

        Enabled folders/categories:
        \(request.folders.map(\.name).joined(separator: ", "))

        Assets:
        \(assetLines(request.assets))
        """
    }

    public static func repairPrompt(
        for request: AssetUnderstandingRequest,
        issues: [InfoPageDraftValidationIssue]
    ) -> String {
        """
        Repair the previous Kairo Library JSON. Return one valid JSON object only.
        Do not reinterpret beyond provided assets.
        Re-run only the failing staged pipeline work and preserve valid source-backed fields.

        Validation errors:
        \(issues.map(\.description).joined(separator: "\n"))

        \(initialPrompt(for: request))
        """
    }

    private static func schemaLine() -> String {
        """
        {"createInfoPage":true,"title":"short title","templateID":"travel|order|warranty|project|event|medical|finance|identityDocument|homeDevice|subscription|recipeOrInstruction|generalNote","category":"same category required by template","assetDescription":"plain description of image or document","ocrSummary":"OCR/user text summary or empty string","keywords":["searchable","terms"],"candidateCategories":[{"folderName":"optional exact folder name","templateID":"travel","category":"travel","confidence":0.0,"reason":"why it fits"}],"summary":"one sentence","facts":[{"label":"required or optional key","value":"source-backed value","sourceAssetID":"uuid"}],"timeline":[{"title":"event","note":"source-backed note","sourceAssetID":"uuid"}],"reminderDrafts":[{"title":"draft title","dueDateText":"optional natural date","needsUserConfirmation":true}],"folderName":"optional exact folder name","confidence":0.0,"missingInfo":["unknown but useful fields"],"sourceAssetIDs":["uuid"]}
        """
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
            do {
                let raw: String
                if attempt == 1, request.executionMode == .staged {
                    raw = try await runStagedUnderstanding(for: request)
                } else {
                    let prompt = attempt == 1
                        ? Self.initialPrompt(for: request)
                        : Self.repairPrompt(for: request, issues: issues)
                    raw = try await model.complete(prompt: prompt)
                }
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

    private func runStagedUnderstanding(for request: AssetUnderstandingRequest) async throws -> String {
        let classification = try await model.complete(
            prompt: AssetUnderstandingPromptBuilder.classifyPrompt(for: request)
        )
        let extractedFacts = try await model.complete(
            prompt: AssetUnderstandingPromptBuilder.extractFactsPrompt(
                for: request,
                classification: classification
            )
        )
        return try await model.complete(
            prompt: AssetUnderstandingPromptBuilder.composePrompt(
                for: request,
                classification: classification,
                extractedFacts: extractedFacts
            )
        )
    }

    public static func initialPrompt(for request: AssetUnderstandingRequest) -> String {
        AssetUnderstandingPromptBuilder.initialPrompt(for: request)
    }

    public static func repairPrompt(for request: AssetUnderstandingRequest, issues: [InfoPageDraftValidationIssue]) -> String {
        AssetUnderstandingPromptBuilder.repairPrompt(for: request, issues: issues)
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
        let sourceAssetIDs = Set(request.assets.map(\.id))
        let fallbackSourceAssetID = sourceAssetIDs.count == 1 ? request.assets.first?.id : nil

        normalized.title = truncate(normalized.title.trimmingCharacters(in: .whitespacesAndNewlines), limit: 96)
        normalized.summary = truncate(normalized.summary.trimmingCharacters(in: .whitespacesAndNewlines), limit: 360)
        normalized.assetDescription = normalized.assetDescription.map {
            truncate($0.trimmingCharacters(in: .whitespacesAndNewlines), limit: 360)
        }
        normalized.ocrSummary = normalized.ocrSummary.map {
            truncate($0.trimmingCharacters(in: .whitespacesAndNewlines), limit: 360)
        }
        normalized.confidence = min(max(normalized.confidence, 0), 1)

        normalized.sourceAssetIDs = uniqueSourceAssetIDs(normalized.sourceAssetIDs, allowed: sourceAssetIDs)
        if normalized.sourceAssetIDs.isEmpty {
            normalized.sourceAssetIDs = request.assets.map(\.id)
        }
        normalized.facts = normalized.facts.compactMap {
            normalizedFact($0, allowedSourceAssetIDs: sourceAssetIDs, fallbackSourceAssetID: fallbackSourceAssetID)
        }
        normalized.timeline = normalized.timeline.compactMap {
            normalizedTimelineItem($0, allowedSourceAssetIDs: sourceAssetIDs, fallbackSourceAssetID: fallbackSourceAssetID)
        }
        normalized.keywords = normalizedStringList(normalized.keywords, limit: 8, maxLength: 40)
        normalized.missingInfo = normalizedStringList(normalized.missingInfo, limit: 8, maxLength: 96) ?? []
        normalized.candidateCategories = normalizedCandidates(normalized.candidateCategories, folders: request.folders)
        return normalized
    }

    private static func normalizedFact(
        _ fact: InfoPageDraftFact,
        allowedSourceAssetIDs: Set<UUID>,
        fallbackSourceAssetID: UUID?
    ) -> InfoPageDraftFact? {
        let label = truncate(fact.label.trimmingCharacters(in: .whitespacesAndNewlines), limit: 48)
        let value = truncate(fact.value.trimmingCharacters(in: .whitespacesAndNewlines), limit: 220)
        guard !label.isEmpty, !value.isEmpty else { return nil }
        let sourceAssetID: UUID?
        if let id = fact.sourceAssetID {
            sourceAssetID = allowedSourceAssetIDs.contains(id) ? id : nil
        } else {
            sourceAssetID = fallbackSourceAssetID
        }
        return InfoPageDraftFact(label: label, value: value, sourceAssetID: sourceAssetID)
    }

    private static func normalizedTimelineItem(
        _ item: InfoPageDraftTimelineItem,
        allowedSourceAssetIDs: Set<UUID>,
        fallbackSourceAssetID: UUID?
    ) -> InfoPageDraftTimelineItem? {
        let title = truncate(item.title.trimmingCharacters(in: .whitespacesAndNewlines), limit: 96)
        guard !title.isEmpty else { return nil }
        let note = item.note.map { truncate($0.trimmingCharacters(in: .whitespacesAndNewlines), limit: 220) }
        let sourceAssetID: UUID?
        if let id = item.sourceAssetID {
            sourceAssetID = allowedSourceAssetIDs.contains(id) ? id : nil
        } else {
            sourceAssetID = fallbackSourceAssetID
        }
        return InfoPageDraftTimelineItem(title: title, note: note?.isEmpty == true ? nil : note, sourceAssetID: sourceAssetID)
    }

    private static func uniqueSourceAssetIDs(_ ids: [UUID], allowed: Set<UUID>) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.compactMap { id in
            guard allowed.contains(id), seen.insert(id).inserted else { return nil }
            return id
        }
    }

    private static func normalizedStringList(_ values: [String]?, limit: Int, maxLength: Int) -> [String]? {
        guard let values else { return nil }
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            let normalized = truncate(value.trimmingCharacters(in: .whitespacesAndNewlines), limit: maxLength)
            let key = normalized.lowercased()
            guard !normalized.isEmpty, seen.insert(key).inserted else { continue }
            result.append(normalized)
            if result.count == limit { break }
        }
        return result
    }

    private static func normalizedCandidates(
        _ candidates: [InfoPageDraftCategoryCandidate]?,
        folders: [KnowledgeAssetFolder]
    ) -> [InfoPageDraftCategoryCandidate]? {
        guard let candidates else { return nil }
        let folderNames = Set(folders.map(\.name))
        var seen: Set<String> = []
        var result: [InfoPageDraftCategoryCandidate] = []
        for candidate in candidates {
            let folderName = candidate.folderName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let acceptedFolderName = folderName.flatMap { folderNames.contains($0) ? $0 : nil }
            let reason = truncate(candidate.reason.trimmingCharacters(in: .whitespacesAndNewlines), limit: 140)
            let key = "\(acceptedFolderName ?? "")|\(candidate.templateID.rawValue)|\(candidate.category.rawValue)"
            guard !reason.isEmpty, seen.insert(key).inserted else { continue }
            result.append(InfoPageDraftCategoryCandidate(
                folderName: acceptedFolderName,
                templateID: candidate.templateID,
                category: candidate.category,
                confidence: min(max(candidate.confidence, 0), 1),
                reason: reason
            ))
            if result.count == 4 { break }
        }
        return result.isEmpty ? nil : result
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit))
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

}
