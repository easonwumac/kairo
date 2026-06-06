import Foundation

public struct InfoPageGenerationInput: Sendable {
    public var assets: [KnowledgeAsset]
    public var preferredTemplateID: InfoPageTemplateID?
    public var now: Date

    public init(
        assets: [KnowledgeAsset],
        preferredTemplateID: InfoPageTemplateID? = nil,
        now: Date = Date()
    ) {
        self.assets = assets
        self.preferredTemplateID = preferredTemplateID
        self.now = now
    }
}

public enum InfoPageGenerator {
    public static func generate(from input: InfoPageGenerationInput) -> InfoPage {
        let templateID = input.preferredTemplateID ?? inferTemplateID(from: input.assets)
        switch templateID {
        case .travel:
            return generateTravelPage(from: input)
        case .order:
            return generateOrderPage(from: input)
        case .project:
            return generateProjectPage(from: input)
        default:
            return generateGeneralPage(from: input, templateID: templateID)
        }
    }

    public static func inferTemplateID(from assets: [KnowledgeAsset]) -> InfoPageTemplateID {
        let text = combinedText(from: assets)
        if containsAny(text, ["香港", "旅行", "旅遊", "機票", "飯店", "酒店", "接送", "pickup", "flight", "hotel", "trip"]) {
            return .travel
        }
        if containsAny(text, ["訂單", "order", "delivery", "shipment", "tracking", "退款", "退貨"]) {
            return .order
        }
        if containsAny(text, ["專案", "project", "deadline", "todo", "測試", "開發", "milestone"]) {
            return .project
        }
        if containsAny(text, ["保固", "warranty", "serial", "序號"]) {
            return .warranty
        }
        if containsAny(text, ["醫師", "診所", "藥", "medical", "doctor", "clinic"]) {
            return .medical
        }
        if containsAny(text, ["帳單", "付款", "invoice", "payment", "contract"]) {
            return .finance
        }
        return .generalNote
    }

    private static func generateTravelPage(from input: InfoPageGenerationInput) -> InfoPage {
        let text = combinedText(from: input.assets)
        let destination = travelDestination(from: text)
        let title = destination.map { "\($0) Travel" } ?? "Travel Plan"
        let pageID = UUID()
        let facts = compactFacts([
            ("destination", destination),
            ("bookingStatus", bookingStatus(from: text)),
            ("pickup", containsAny(text, ["接送", "pickup"]) ? "Airport pickup found" : nil),
            ("returnTrip", containsAny(text, ["回程", "return"]) ? "Return details found" : "Needs confirmation")
        ], sourceAssetID: input.assets.first?.id)
        let timeline = compactTimeline([
            ("Airport pickup", containsAny(text, ["接送", "pickup"]) ? textPreview(text) : nil),
            ("Return trip", containsAny(text, ["回程", "return"]) ? textPreview(text) : "Not found in linked assets")
        ], sourceAssetID: input.assets.first?.id)
        let reminder = ReminderLink.draft(infoPageID: pageID, title: "Confirm \(destination ?? "travel") checklist")
        let action = AgentAction(
            kind: .createReminderDraft,
            title: KairoL10n.string("actionInbox.action.createReminder"),
            rationale: KairoL10n.string("infoPage.action.rationale.travel"),
            payload: .reminder(ReminderDraft(title: reminder.title, notes: reminder.notesFallback, dueDate: reminder.dueDate)),
            riskTier: .tier2LowRiskWrite
        )
        return InfoPage(
            id: pageID,
            title: title,
            category: .travel,
            templateID: .travel,
            summary: "Travel page built from \(input.assets.count) linked asset(s).",
            facts: facts,
            timeline: timeline,
            assetIDs: input.assets.map(\.id),
            reminderLinks: [reminder],
            actionDrafts: [action],
            createdAt: input.now,
            updatedAt: input.now
        )
    }

    private static func generateOrderPage(from input: InfoPageGenerationInput) -> InfoPage {
        let text = combinedText(from: input.assets)
        return InfoPage(
            title: "Order",
            category: .order,
            templateID: .order,
            summary: "Order page built from \(input.assets.count) linked asset(s).",
            facts: compactFacts([
                ("merchant", firstKnownValue(in: text, candidates: ["Apple", "Amazon", "Uber", "Booking"]) ?? "Unknown merchant"),
                ("orderStatus", containsAny(text, ["delivered", "已送達"]) ? "Delivered" : "Needs review"),
                ("orderNumber", firstOrderNumber(in: text))
            ], sourceAssetID: input.assets.first?.id),
            timeline: compactTimeline([
                ("Delivery", containsAny(text, ["delivery", "配送", "送達"]) ? textPreview(text) : nil),
                ("Return deadline", containsAny(text, ["return", "退貨"]) ? textPreview(text) : nil)
            ], sourceAssetID: input.assets.first?.id),
            assetIDs: input.assets.map(\.id),
            createdAt: input.now,
            updatedAt: input.now
        )
    }

    private static func generateProjectPage(from input: InfoPageGenerationInput) -> InfoPage {
        let text = combinedText(from: input.assets)
        let pageID = UUID()
        let reminder = ReminderLink.draft(infoPageID: pageID, title: "Review project next step")
        let action = AgentAction(
            kind: .createReminderDraft,
            title: KairoL10n.string("actionInbox.action.createReminder"),
            rationale: KairoL10n.string("infoPage.action.rationale.project"),
            payload: .reminder(ReminderDraft(title: reminder.title, notes: reminder.notesFallback, dueDate: reminder.dueDate)),
            riskTier: .tier2LowRiskWrite
        )
        return InfoPage(
            id: pageID,
            title: projectTitle(from: text),
            category: .project,
            templateID: .project,
            summary: textPreview(text),
            facts: compactFacts([
                ("goal", textPreview(text)),
                ("nextStep", containsAny(text, ["測試", "test"]) ? "Run focused tests" : "Review next step")
            ], sourceAssetID: input.assets.first?.id),
            timeline: compactTimeline([
                ("Next step", textPreview(text))
            ], sourceAssetID: input.assets.first?.id),
            assetIDs: input.assets.map(\.id),
            reminderLinks: [reminder],
            actionDrafts: [action],
            createdAt: input.now,
            updatedAt: input.now
        )
    }

    private static func generateGeneralPage(from input: InfoPageGenerationInput, templateID: InfoPageTemplateID) -> InfoPage {
        let definition = InfoPageTemplateCatalog.definition(for: templateID)
        let text = combinedText(from: input.assets)
        return InfoPage(
            title: input.assets.first?.title ?? "Info Page",
            category: definition.category,
            templateID: templateID,
            summary: textPreview(text),
            facts: compactFacts([
                ("topic", input.assets.first?.title ?? "Imported asset")
            ], sourceAssetID: input.assets.first?.id),
            assetIDs: input.assets.map(\.id),
            createdAt: input.now,
            updatedAt: input.now
        )
    }

    private static func combinedText(from assets: [KnowledgeAsset]) -> String {
        assets.map { asset in
            [
                asset.title,
                asset.summary,
                asset.generatedDescription ?? "",
                asset.extractedText,
                asset.tags.joined(separator: " "),
                asset.attachments.map(\.displayName).joined(separator: " ")
            ].joined(separator: "\n")
        }
        .joined(separator: "\n")
    }

    private static func compactFacts(_ pairs: [(String, String?)], sourceAssetID: UUID?) -> [InfoPageFact] {
        pairs.compactMap { label, value in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return InfoPageFact(label: label, value: value, sourceAssetID: sourceAssetID)
        }
    }

    private static func compactTimeline(_ pairs: [(String, String?)], sourceAssetID: UUID?) -> [InfoPageTimelineItem] {
        pairs.compactMap { title, note in
            guard let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return InfoPageTimelineItem(title: title, note: note, sourceAssetID: sourceAssetID)
        }
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func travelDestination(from text: String) -> String? {
        if text.localizedCaseInsensitiveContains("香港") || text.localizedCaseInsensitiveContains("hong kong") {
            return "Hong Kong"
        }
        if text.localizedCaseInsensitiveContains("日本") || text.localizedCaseInsensitiveContains("japan") {
            return "Japan"
        }
        return nil
    }

    private static func bookingStatus(from text: String) -> String {
        containsAny(text, ["已預訂", "confirmed", "booked"]) ? "Booked" : "Needs review"
    }

    private static func projectTitle(from text: String) -> String {
        if text.localizedCaseInsensitiveContains("Kairo") {
            return "Kairo Project"
        }
        return "Project"
    }

    private static func firstKnownValue(in text: String, candidates: [String]) -> String? {
        candidates.first { text.localizedCaseInsensitiveContains($0) }
    }

    private static func firstOrderNumber(in text: String) -> String? {
        let pattern = #"(?i)(order|訂單)[^\nA-Z0-9]{0,8}([A-Z0-9-]{5,})"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            match.numberOfRanges >= 3,
            let range = Range(match.range(at: 2), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func textPreview(_ text: String, limit: Int = 180) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Imported asset" }
        return String(trimmed.prefix(limit))
    }
}
