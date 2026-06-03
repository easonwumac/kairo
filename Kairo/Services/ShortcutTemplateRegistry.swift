import Foundation

public struct ShortcutTemplateRegistry: Codable, Equatable, Sendable {
    public var templates: [ShortcutTemplate]
    public var manualInstallDisclaimer: String

    public init(
        templates: [ShortcutTemplate],
        manualInstallDisclaimer: String = "Kairo creates internal recipes. Apple Shortcuts installation requires user approval."
    ) {
        self.templates = templates
        self.manualInstallDisclaimer = manualInstallDisclaimer
    }

    public func template(id: String) -> ShortcutTemplate? {
        templates.first { $0.identifier == id }
    }

    public static let `default` = ShortcutTemplateRegistry(templates: [
        ShortcutTemplate(
            identifier: "daily-briefing-shortcut",
            title: "Daily Briefing Shortcut",
            description: "Shortcut template guidance for running the Kairo Daily Briefing recipe from Siri, widgets, or a personal morning automation.",
            category: .dailyBriefing,
            inputSummary: "Optional text from Shortcuts or Siri.",
            outputSummary: "Kairo recipe run summary and draft actions.",
            requiredIntentIdentifiers: ["RunKairoDailyBriefingIntent", "RunKairoRecipeIntent"],
            recommendedRecipeTemplateID: "daily-briefing",
            setupInstructions: [
                "Open Apple Shortcuts and create a new personal Shortcut.",
                "Add Run Kairo Daily Briefing, or add Run Kairo Recipe with Recipe ID daily-briefing.",
                "Review the Shortcut actions and approve installation yourself."
            ]
        ),
        ShortcutTemplate(
            identifier: "meeting-prep-shortcut",
            title: "Meeting Prep Shortcut",
            description: "Shortcut template guidance for preparing a meeting brief from Kairo memory.",
            category: .meetingPrep,
            inputSummary: "Optional meeting title or Shortcut text.",
            outputSummary: "Meeting prep summary returned by Kairo.",
            requiredIntentIdentifiers: ["RunKairoRecipeIntent"],
            recommendedRecipeTemplateID: "meeting-prep",
            setupInstructions: [
                "Open Apple Shortcuts and create a Shortcut before meetings.",
                "Add Run Kairo Recipe with Recipe ID meeting-prep.",
                "Keep any calendar trigger user-created and user-approved."
            ]
        ),
        ShortcutTemplate(
            identifier: "share-text-to-kairo-shortcut",
            title: "Share Text to Kairo Shortcut",
            description: "Shortcut template guidance for sending selected text into a Kairo internal recipe.",
            category: .shareSheet,
            inputSummary: "Shared text or Shortcut input.",
            outputSummary: "Summary and task drafts created inside Kairo.",
            requiredIntentIdentifiers: ["SaveToKairoMemoryIntent", "RunKairoRecipeIntent"],
            recommendedRecipeTemplateID: "shared-text-to-tasks",
            setupInstructions: [
                "Create a Share Sheet Shortcut that accepts text.",
                "Pass Shortcut Input to Run Kairo Recipe with Recipe ID shared-text-to-tasks.",
                "Review any returned drafts in Kairo before external writes."
            ]
        ),
        ShortcutTemplate(
            identifier: "screenshot-to-tasks-shortcut",
            title: "Screenshot to Tasks Shortcut",
            description: "Shortcut template guidance for using user-approved OCR text as Kairo task input.",
            category: .screenshotToTasks,
            inputSummary: "OCR text extracted by a user-created Shortcut.",
            outputSummary: "Reminder drafts returned by Kairo.",
            requiredIntentIdentifiers: ["ExtractKairoTasksIntent", "RunKairoRecipeIntent"],
            recommendedRecipeTemplateID: "shared-text-to-tasks",
            setupInstructions: [
                "Create an Apple Shortcut that gets a screenshot and extracts text.",
                "Send that text to Run Kairo Recipe with Recipe ID shared-text-to-tasks.",
                "Approve the Shortcut manually and keep Reminder writes user-confirmed."
            ]
        ),
        ShortcutTemplate(
            identifier: "email-triage-shortcut",
            title: "Email Triage Shortcut",
            description: "Shortcut template guidance for summarizing an email, extracting follow-up tasks, and drafting a reply without sending.",
            category: .shareSheet,
            inputSummary: "Email thread text explicitly selected, copied, or shared by the user.",
            outputSummary: "Email summary, follow-up task drafts, and reply draft for manual review.",
            requiredIntentIdentifiers: ["SummarizeWithKairoIntent", "ExtractKairoTasksIntent", "RunKairoShortcutNodeIntent"],
            recommendedRecipeTemplateID: "email-triage",
            setupInstructions: [
                "Create a Share Sheet Shortcut that accepts text from Mail or copied email content.",
                "Pass Shortcut Input to Summarize with Kairo, then chain it through Extract Kairo Tasks and Draft Reply.",
                "Show the returned task and reply drafts for review; do not send email or write reminders silently."
            ]
        ),
        ShortcutTemplate(
            identifier: "message-reply-handoff-shortcut",
            title: "Message Reply Handoff Shortcut",
            description: "Shortcut template guidance for preparing a visible Messages handoff from explicit text without sending.",
            category: .shareSheet,
            inputSummary: "Message body text and optional recipient explicitly provided by the user.",
            outputSummary: "Messages recipient handoff preview with body text kept in Kairo.",
            requiredIntentIdentifiers: ["PrepareMessageHandoffIntent", "RunKairoShortcutNodeIntent"],
            recommendedRecipeTemplateID: "message-reply-handoff",
            setupInstructions: [
                "Create a Share Sheet or manual Shortcut that accepts text or asks for a message body.",
                "Pass the body and optional recipient to Prepare Message Handoff.",
                "Show the returned preview; do not send messages silently and remember the body remains in Kairo instead of the sms: URL."
            ]
        ),
        ShortcutTemplate(
            identifier: "phone-call-handoff-shortcut",
            title: "Phone Call Handoff Shortcut",
            description: "Shortcut template guidance for preparing a visible Phone handoff from explicit phone text without placing calls automatically.",
            category: .shareSheet,
            inputSummary: "Phone number plus optional label or notes explicitly provided by the user.",
            outputSummary: "Phone handoff preview, tel: URL, and proposed action for manual review.",
            requiredIntentIdentifiers: ["PreparePhoneCallHandoffIntent", "RunKairoShortcutNodeIntent"],
            recommendedRecipeTemplateID: "phone-call-handoff",
            setupInstructions: [
                "Create a Share Sheet, Action Button, or manual Shortcut that accepts phone text.",
                "Pass the phone number and optional label to Prepare Phone Call Handoff.",
                "Show the returned tel: preview; do not place calls silently and require the user to continue in Phone."
            ]
        ),
        ShortcutTemplate(
            identifier: "contact-draft-shortcut",
            title: "Contact Draft Shortcut",
            description: "Shortcut template guidance for creating a Contacts.framework draft from explicit text without writing Contacts silently.",
            category: .shareSheet,
            inputSummary: "Name plus optional phone, email, and notes explicitly provided by the user.",
            outputSummary: "Contact draft JSON and a proposed Contacts.framework action for Kairo review.",
            requiredIntentIdentifiers: ["CreateContactDraftsIntent", "RunKairoShortcutNodeIntent"],
            recommendedRecipeTemplateID: "contact-draft-from-shared-text",
            setupInstructions: [
                "Create a Share Sheet or manual Shortcut that accepts contact text.",
                "Pass name, phone, email, and notes into Create Contact Drafts.",
                "Show the returned draft; do not write Contacts silently and require Kairo preview and confirmation before any Contacts.framework write."
            ]
        ),
        ShortcutTemplate(
            identifier: "calendar-draft-shortcut",
            title: "Calendar Draft Shortcut",
            description: "Shortcut template guidance for turning meeting text into a calendar draft without writing EventKit automatically.",
            category: .meetingPrep,
            inputSummary: "Meeting title or schedule text, plus optional startDateISO and endDateISO variables.",
            outputSummary: "Calendar draft JSON for manual review before any EventKit write.",
            requiredIntentIdentifiers: ["CreateCalendarDraftsIntent", "RunKairoShortcutNodeIntent"],
            recommendedRecipeTemplateID: "meeting-text-to-calendar-draft",
            setupInstructions: [
                "Create a Shortcut that accepts text or asks for a meeting title.",
                "Pass the text to Create Calendar Drafts, optionally adding startDateISO and endDateISO variables.",
                "Show the returned calendar draft and require user confirmation before any EventKit calendar write."
            ]
        ),
        ShortcutTemplate(
            identifier: "email-draft-shortcut",
            title: "Email Draft Shortcut",
            description: "Shortcut template guidance for turning selected text into an email draft without sending.",
            category: .shareSheet,
            inputSummary: "Email body text plus optional recipient and subject values.",
            outputSummary: "Email draft JSON and a proposed compose action for manual review.",
            requiredIntentIdentifiers: ["CreateEmailDraftsIntent", "RunKairoShortcutNodeIntent"],
            recommendedRecipeTemplateID: "email-draft-from-shared-text",
            setupInstructions: [
                "Create a Share Sheet or manual Shortcut that accepts text.",
                "Pass the text to Create Email Drafts, optionally setting recipient and subject.",
                "Show the returned email draft and do not send email automatically."
            ]
        ),
        ShortcutTemplate(
            identifier: "action-button-ask-kairo-shortcut",
            title: "Action Button Ask Kairo Shortcut",
            description: "Shortcut template guidance for mapping the Action Button to a visible Ask Kairo handoff.",
            category: .actionButton,
            inputSummary: "Prompt text typed or dictated by a user-created Shortcut.",
            outputSummary: "Kairo answer JSON and spoken/displayable text.",
            requiredIntentIdentifiers: ["AskKairoIntent"],
            setupInstructions: [
                "Create a Shortcut that asks for text and passes it to Ask Kairo.",
                "Assign that Shortcut to Action Button in iOS Settings.",
                "Kairo does not create or edit the Action Button Shortcut for you."
            ]
        ),
        ShortcutTemplate(
            identifier: "run-kairo-recipe-shortcut",
            title: "Run Kairo Recipe Shortcut",
            description: "Generic template guidance for calling any enabled Kairo internal recipe by ID.",
            category: .genericRecipe,
            inputSummary: "Recipe ID and optional text input.",
            outputSummary: "Kairo recipe run summary and structured result JSON.",
            requiredIntentIdentifiers: ["RunKairoRecipeIntent"],
            setupInstructions: [
                "Create an Apple Shortcut and add the Run Kairo Recipe action.",
                "Enter the Recipe ID from Kairo Automations.",
                "Run the Shortcut only after reviewing the user-approved setup."
            ]
        )
    ])
}
