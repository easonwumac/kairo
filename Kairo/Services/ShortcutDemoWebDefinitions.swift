import Foundation

public extension ShortcutDemoCatalog {
    static let webRecipes: [ShortcutDemoRecipe] = [
        ShortcutDemoRecipe(
            id: "web-search-handoff",
            title: "Web Search Handoff",
            summary: "Prepare a visible Safari search handoff from explicit query text without browsing automatically.",
            triggerSummary: "Share Sheet text, Action Button, or manual Shortcut query input.",
            setupNotes: [
                "Pass the query into Prepare Web Search Handoff.",
                "Show the returned DuckDuckGo URL and require the user to continue in Safari.",
                "Do not browse silently, scrape pages, or read web content in the background."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Prepare Web Search Handoff with Kairo",
                    nodeKind: .prepareWebSearchHandoff,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables.query"],
                        description: "Search query explicitly provided by the user."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.webSearchHandoffCount", "fields.webSearchQuery", "fields.webSearchRequiresConfirmation"],
                        optionalFields: ["fields.webSearchURL", "fields.chainText", "webSearchDrafts", "proposedActions"],
                        description: "Safari/DuckDuckGo handoff preview only. No browsing happens until the user continues visibly."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "Search web for SwiftUI App Intents examples",
                        sourceName: "Search Shortcut",
                        variables: [
                            "shortcutRecipeID": "web-search-handoff",
                            "query": "SwiftUI App Intents examples"
                        ]
                    )
                )
            ]
        )
    ]
}
