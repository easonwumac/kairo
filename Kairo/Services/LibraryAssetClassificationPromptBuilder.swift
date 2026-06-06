import Foundation

public enum LibraryAssetClassificationPromptBuilder {
    public static func context(for attachments: [ChatAttachment]) -> String {
        guard !attachments.isEmpty else {
            return "Library classification: no asset attachments for this turn."
        }

        let templates = InfoPageTemplateCatalog.all
            .map { "\($0.id.rawValue)=\($0.category.rawValue)" }
            .joined(separator: ", ")

        return """
        Library classification:
        Use attachment OCR/labels as imperfect references. Do not claim direct vision unless the runtime supports image input.
        Pick one template or keep raw asset. The app renders fixed templates from JSON; never generate HTML.
        Return compact JSON only: {"templateID":"...","category":"...","createInfoPage":true|false,"confidence":0-1,"missing":[]}.
        Templates:
        \(templates)
        """
    }
}
