import Foundation

public extension ShortcutDemoCatalog {
    static let contactRecipes: [ShortcutDemoRecipe] = [
        ShortcutDemoRecipe(
            id: "contact-draft-from-shared-text",
            title: "Contact Draft from Shared Text",
            summary: "Turn explicit contact text into a Contacts.framework draft for visible review.",
            triggerSummary: "Share Sheet, copied signature, business card text, or manual Shortcut input.",
            setupNotes: [
                "Pass name, phone, email, and notes text into Create Contact Drafts.",
                "Show the returned contact draft before any Contacts.framework write.",
                "Do not write Contacts automatically; Kairo returns draft data only."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Create Contact Draft with Kairo",
                    nodeKind: .createContactDraft,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables.name", "variables.phone", "variables.email", "variables.notes"],
                        description: "Contact details explicitly provided by the user."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.contactDraftCount", "fields.contactDisplayName", "fields.contactRequiresConfirmation"],
                        optionalFields: ["fields.contactPhoneCount", "fields.contactEmailCount", "fields.chainText", "contactDrafts", "proposedActions"],
                        description: "Contact draft JSON and proposed Contacts action for manual confirmation."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        Name: Alex Chen
                        Phone: +1-555-0100
                        Email: alex@example.com
                        Notes: Met at WWDC and wants the Kairo TestFlight link.
                        """,
                        sourceName: "Shared Contact Text",
                        variables: ["shortcutRecipeID": "contact-draft-from-shared-text"]
                    )
                )
            ]
        )
    ]
}
