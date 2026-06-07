import Foundation

public enum LibraryAssetClassificationPromptBuilder {
    public static func context(for attachments: [ChatAttachment]) -> String {
        guard !attachments.isEmpty else {
            return "Library classification: no asset attachments for this turn."
        }

        let enabledCategories = KairoOnboarding.defaultCategories
            .map { "\($0.id)=\(KairoL10n.string($0.titleKey))" }
            .joined(separator: ", ")

        return """
        Library asset classification task:
        Analyze each attached image using visual content only.
        Classify the asset against enabled categories, then fill ALL template fields.
        Return ONLY a compact JSON object. No markdown fences, no prose, no extra text before or after.
        ALL of these fields are REQUIRED and must be present in the output:

        Required JSON shape:
        {"createInfoPage":true,"title":"short title","templateID":"travel|order|warranty|project|event|medical|finance|identityDocument|homeDevice|subscription|recipeOrInstruction|generalNote","category":"same as templateID","assetDescription":"description of what is visible","ocrSummary":"text visible in image or empty string","keywords":["term1","term2"],"candidateCategories":[{"folderName":"optional folder","templateID":"travel","category":"travel","confidence":0.9,"reason":"why it fits"}],"selectedSubcategoryIDs":[],"suggestedSubcategoryName":null,"summary":"one sentence","facts":[{"label":"fact label","value":"fact value","sourceAssetID":null}],"timeline":[{"title":"event","note":"description","sourceAssetID":null}],"reminderDrafts":[],"folderName":"optional exact enabled folder","confidence":0.9,"missingInfo":["field1","field2"],"sourceAssetIDs":[]}

        Enabled categories: \(enabledCategories)
        """

        //        let templates = InfoPageTemplateCatalog.all
        //            .map { definition in
        //                "\(definition.id.rawValue): category=\(definition.category.rawValue), required=\(definition.requiredFactKeys.joined(separator: ",")), optional=\(definition.optionalFactKeys.joined(separator: ","))"
        //            }
        //            .joined(separator: "\n")
        //        Templates:
        //        \(templates)
    }
}
