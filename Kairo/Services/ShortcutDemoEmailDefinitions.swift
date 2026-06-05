import Foundation

public extension ShortcutDemoCatalog {
    static let communicationRecipes: [ShortcutDemoRecipe] = [
        ShortcutDemoRecipe(
            id: "reply-draft-from-shared-text",
            title: "Reply Draft from Shared Text",
            summary: "Turn explicitly shared email or chat text into a draft reply without sending anything automatically.",
            triggerSummary: "Share Sheet from Mail, Messages-compatible exports, Safari, or any app that shares text.",
            setupNotes: [
                "Pass shared text to Summarize with Kairo.",
                "Pass the previous Kairo output to Draft Reply and review the returned text before sending manually."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Summarize with Kairo",
                    nodeKind: .summarize,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables"],
                        description: "Email, chat, or support request text explicitly selected by the user."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["displayText", "fields.summary", "fields.chainText"],
                        description: "Concise context passed into the reply drafting node."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        Customer email:
                        Can Kairo turn a screenshot into reminders and keep the Shortcut output structured?
                        """,
                        sourceName: "Shared Email",
                        variables: ["shortcutRecipeID": "reply-draft-from-shared-text"]
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Draft Reply with Kairo",
                    nodeKind: .draftReply,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["previousStepOutput", "variables"],
                        description: "Previous Kairo summary or explicit Shortcut input text."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.replyDraft"],
                        optionalFields: ["fields.replyDraftTone", "displayText"],
                        description: "Reply draft text only. The Shortcut must still ask the user before sending."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "",
                        sourceName: "Shared Email",
                        variables: [
                            "shortcutRecipeID": "reply-draft-from-shared-text",
                            "kairoInputSource": "previousStepOutput",
                            "tone": "concise"
                        ]
                    )
                )
            ]
        ),
        ShortcutDemoRecipe(
            id: "message-reply-handoff",
            title: "Message Reply Handoff",
            summary: "Prepare a visible Messages recipient handoff from explicit text without sending automatically.",
            triggerSummary: "Share Sheet, copied chat text, Action Button, or manual Shortcut text input.",
            setupNotes: [
                "Pass the message body plus an optional recipient into Prepare Message Handoff.",
                "Show the returned body and recipient for review before opening Messages.",
                "Do not send messages silently; the body remains in Kairo because sms: URLs only carry the recipient handoff."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Prepare Message Handoff with Kairo",
                    nodeKind: .prepareMessageHandoff,
                    integrationSkillID: .appleMessagesHandoff,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables.recipient", "variables.body"],
                        description: "Message body text explicitly provided by the user, with optional recipient variable."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.messageHandoffCount", "fields.messageBodyInURL", "fields.messageRequiresConfirmation"],
                        optionalFields: ["fields.messageRecipient", "fields.messageBody", "fields.messageHandoffURL", "fields.chainText", "proposedActions"],
                        description: "Messages handoff preview only. The sms: URL omits body text and no message is sent."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "Please tell Alex I am running late but will join in 10 minutes.",
                        sourceName: "Shared Message",
                        variables: [
                            "shortcutRecipeID": "message-reply-handoff",
                            ShortcutNodeInput.integrationSkillIDVariableKey: AppIntegrationSkillID.appleMessagesHandoff.rawValue,
                            "recipient": "0912345678",
                            "body": "I am running late but will join in 10 minutes."
                        ]
                    )
                )
            ]
        ),
        ShortcutDemoRecipe(
            id: "email-triage",
            title: "Email Triage",
            summary: "Summarize an email, extract follow-up tasks, and prepare a reply draft without sending.",
            triggerSummary: "Share Sheet from Mail, a copied email thread, or an Action Button Shortcut that passes selected text.",
            setupNotes: [
                "Pass the selected email text to Summarize with Kairo.",
                "Chain the output through Extract Kairo Tasks and Draft Reply.",
                "Show task and reply drafts for manual review; do not send or write reminders silently."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Summarize Email with Kairo",
                    nodeKind: .summarize,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables"],
                        description: "Email thread text explicitly selected or shared by the user."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["displayText", "fields.summary", "fields.chainText"],
                        description: "Compact email summary and original text for downstream Kairo nodes."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        Email from vendor:
                        Please confirm the revised launch timeline by Friday.
                        Action: Send updated app screenshots
                        Reminder: Ask legal to review the OAuth wording
                        """,
                        sourceName: "Shared Email",
                        variables: ["shortcutRecipeID": "email-triage"]
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Extract Follow-up Tasks",
                    nodeKind: .extractTasks,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["previousStepOutput", "variables"],
                        description: "Email summary or original text passed from the previous Kairo node."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.taskCount", "fields.chainText"],
                        optionalFields: ["tasks", "reminderDrafts"],
                        description: "Follow-up task drafts plus chain text for reply drafting."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "",
                        sourceName: "Shared Email",
                        variables: [
                            "shortcutRecipeID": "email-triage",
                            "kairoInputSource": "previousStepOutput"
                        ]
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Draft Email Reply",
                    nodeKind: .draftReply,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["previousStepOutput", "variables"],
                        description: "Email text chained from the task extraction node."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.replyDraft"],
                        optionalFields: ["fields.replyDraftTone", "displayText"],
                        description: "Reply draft only. Shortcuts must still require visible user review before sending."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "",
                        sourceName: "Shared Email",
                        variables: [
                            "shortcutRecipeID": "email-triage",
                            "kairoInputSource": "previousStepOutput",
                            "tone": "clear"
                        ]
                    )
                )
            ]
        ),
        ShortcutDemoRecipe(
            id: "email-draft-from-shared-text",
            title: "Email Draft from Shared Text",
            summary: "Turn explicitly shared or typed text into a structured email draft for visible review.",
            triggerSummary: "Share Sheet, copied note, Action Button, or manual Shortcut text input.",
            setupNotes: [
                "Pass text plus optional recipient and subject variables to Create Email Drafts.",
                "Show the returned draft in Shortcuts or Kairo before opening Mail.",
                "Do not send email automatically; Kairo returns draft data only."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Create Email Draft with Kairo",
                    nodeKind: .createEmailDraft,
                    integrationSkillID: .appleMailHandoff,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables.recipient", "variables.subject"],
                        description: "Email body text explicitly provided by the user, with optional recipient and subject variables."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.emailDraftCount", "fields.emailSubject", "fields.emailRequiresConfirmation"],
                        optionalFields: ["fields.emailRecipientCount", "fields.chainText", "emailDrafts", "proposedActions"],
                        description: "Email draft JSON and a proposed compose action for manual review. No email is sent."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        To: ops@example.com
                        Subject: Kairo rollout check
                        Please review the latest Shortcut node rollout and confirm any blockers before Friday.
                        """,
                        sourceName: "Shared Text Shortcut",
                        variables: [
                            "shortcutRecipeID": "email-draft-from-shared-text",
                            ShortcutNodeInput.integrationSkillIDVariableKey: AppIntegrationSkillID.appleMailHandoff.rawValue
                        ]
                    )
                )
            ]
        )
    ]
}
