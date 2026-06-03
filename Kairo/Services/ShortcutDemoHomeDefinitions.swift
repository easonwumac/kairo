import Foundation

public extension ShortcutDemoCatalog {
    static let homeRecipes: [ShortcutDemoRecipe] = [
        ShortcutDemoRecipe(
            id: "home-action-preview",
            title: "Home Action Preview",
            summary: "Let a Shortcut ask Kairo for a HomeKit action preview while Kairo keeps the actual write behind confirmation.",
            triggerSummary: "Action Button, Siri, or manual Shortcut that passes a requested home action.",
            setupNotes: [
                "Pass a natural-language home request plus optional homeName, roomName, targetName, command, and value variables.",
                "Use the returned proposedActions only as a visible preview in Kairo.",
                "Do not run HomeKit writes from Shortcuts without Kairo showing confirmation first."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Preview Home Action with Kairo",
                    nodeKind: .previewHomeAction,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables"],
                        description: "A user-approved home request and optional structured target hints from Shortcuts."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["proposedActions", "fields.homeActionCount", "fields.homeActionRiskTier"],
                        optionalFields: ["fields.homeActionRequiresConfirmation", "displayText"],
                        description: "HomeKit action preview only. Kairo still requires visible in-app confirmation before any write."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "Turn on the office desk lamp",
                        sourceName: "Home Shortcut",
                        variables: [
                            "shortcutRecipeID": "home-action-preview",
                            "homeName": "Home",
                            "roomName": "Office",
                            "targetName": "Desk Lamp",
                            "command": "setPower",
                            "value": "true"
                        ]
                    )
                )
            ]
        )
    ]
}
