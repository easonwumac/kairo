import Foundation

public extension ShortcutDemoCatalog {
    static let phoneRecipes: [ShortcutDemoRecipe] = [
        ShortcutDemoRecipe(
            id: "phone-call-handoff",
            title: "Phone Call Handoff",
            summary: "Prepare a visible Phone handoff from explicit phone text without placing calls automatically.",
            triggerSummary: "Share Sheet, copied contact text, Action Button, or manual Shortcut input.",
            setupNotes: [
                "Pass the phone number and optional label into Prepare Phone Call Handoff.",
                "Show the returned tel: preview before opening Phone.",
                "Do not place calls silently; the user must still confirm in the Phone surface."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Prepare Phone Call Handoff with Kairo",
                    nodeKind: .preparePhoneCallHandoff,
                    integrationSkillID: .applePhoneHandoff,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables.phoneNumber", "variables.label"],
                        description: "Phone number text explicitly provided by the user, with an optional display label."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.phoneCallHandoffCount", "fields.phoneCallNumber", "fields.phoneCallRequiresConfirmation"],
                        optionalFields: ["fields.phoneCallLabel", "fields.phoneCallURL", "fields.chainText", "phoneCallDrafts", "proposedActions"],
                        description: "Phone handoff preview and proposed tel: action for manual review. No call is placed."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "Call Alex at +1 (555) 0100 about the Kairo TestFlight.",
                        sourceName: "Shared Phone Text",
                        variables: [
                            "shortcutRecipeID": "phone-call-handoff",
                            ShortcutNodeInput.integrationSkillIDVariableKey: AppIntegrationSkillID.applePhoneHandoff.rawValue,
                            "phoneNumber": "+1 (555) 0100",
                            "label": "Alex"
                        ]
                    )
                )
            ]
        )
    ]
}
