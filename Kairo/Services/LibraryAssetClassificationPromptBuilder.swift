import Foundation

public enum LibraryAssetClassificationPromptBuilder {
    public static func context(for attachments: [ChatAttachment]) -> String {
        guard !attachments.isEmpty else {
            return "Library classification: no asset attachments for this turn."
        }

        let templates = InfoPageTemplateCatalog.all
            .map { definition in
                "\(definition.id.rawValue): category=\(definition.category.rawValue), required=\(definition.requiredFactKeys.joined(separator: ",")), optional=\(definition.optionalFactKeys.joined(separator: ","))"
            }
            .joined(separator: "\n")
        let enabledCategories = KairoOnboarding.defaultCategories
            .map { "\($0.id)=\(KairoL10n.string($0.titleKey))" }
            .joined(separator: ", ")

        return """
        Library asset classification task:
        Use attachment OCR, Apple Vision labels, file metadata, and user text as source references.
        First classify the asset against enabled categories, then fill fixed template fields.
        Return one compact JSON object only. No Markdown. No HTML. No prose before or after JSON.
        If more than one category is plausible, include 2-4 candidateCategories so the app can ask the user to choose.
        If confidence is low, set createInfoPage=false and still return assetDescription, keywords, and candidateCategories.
        Do not ask which language or topic to use.

        Required JSON shape:
        {"createInfoPage":true,"title":"short title","templateID":"travel|order|warranty|project|event|medical|finance|identityDocument|homeDevice|subscription|recipeOrInstruction|generalNote","category":"same category required by template","assetDescription":"image/document description","ocrSummary":"OCR/user text summary or empty string","keywords":["searchable","terms"],"candidateCategories":[{"folderName":"optional enabled category or folder name","templateID":"travel","category":"travel","confidence":0.0,"reason":"why it fits"}],"summary":"one sentence","facts":[{"label":"required or optional key","value":"source-backed value","sourceAssetID":"uuid if known"}],"timeline":[{"title":"event","note":"source-backed note","sourceAssetID":"uuid if known"}],"reminderDrafts":[{"title":"draft title","dueDateText":"optional natural date","needsUserConfirmation":true}],"folderName":"optional exact enabled folder/category","confidence":0.0,"missingInfo":["unknown but useful fields"],"sourceAssetIDs":[]}

        Enabled categories:
        \(enabledCategories)

        Templates:
        \(templates)
        """
    }
}
