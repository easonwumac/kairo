import Foundation

public enum LibraryAssetClassificationPromptBuilder {
    public static func context(for attachments: [ChatAttachment]) -> String {
        guard !attachments.isEmpty else {
            return "Library classification: no asset attachments for this turn."
        }

        let templates = InfoPageTemplateCatalog.all.map { definition in
            """
            {"id":"\(definition.id.rawValue)","category":"\(definition.category.rawValue)","view":"\(definition.htmlTemplateName)","required":\(jsonArray(definition.requiredFactKeys)),"optional":\(jsonArray(definition.optionalFactKeys)),"timeline":\(jsonArray(definition.timelineKeys)),"reminders":\(jsonArray(definition.suggestedReminderKeys))}
            """
        }.joined(separator: "\n")

        return """
        Library classification:
        Use attachment OCR/labels as imperfect references. Do not claim direct vision unless the runtime supports image input.
        Pick one template or keep raw asset. HTML is rendered by fixed templates from JSON; do not generate HTML source.
        Return compact JSON: {"templateID": "...", "category": "...", "view": "...", "createInfoPage": true|false, "confidence": 0-1, "facts": {}, "missing": [], "folder": "..."}.
        Templates:
        \(templates)
        """
    }

    private static func jsonArray(_ values: [String]) -> String {
        "[" + values.map { "\"\($0)\"" }.joined(separator: ",") + "]"
    }
}
