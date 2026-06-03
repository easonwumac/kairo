import Foundation

public struct KairoRecipePlanner: Sendable {
    public init() {}

    public func suggestRecipes(for request: String, now: Date = Date()) -> [KairoRecipe] {
        let normalized = request.lowercased()
        var recipes: [KairoRecipe] = []

        if containsAny(normalized, ["每天", "daily", "morning", "早上"]) {
            recipes.append(suggested(KairoRecipeTemplateFactory.dailyBriefing(now: now)))
        }
        if containsAny(normalized, ["meeting", "會議", "calendar"]) {
            recipes.append(suggested(KairoRecipeTemplateFactory.meetingPrep(now: now)))
        }
        if containsAny(normalized, ["todo", "待辦", "reminder", "提醒"]) {
            recipes.append(suggested(KairoRecipeTemplateFactory.sharedTextToTasks(now: now)))
        }
        if containsAny(normalized, ["keyboard", "鍵盤"]) {
            recipes.append(suggested(KairoRecipeTemplateFactory.keyboardTodoCapture(now: now)))
        }
        if containsAny(normalized, ["home", "homekit", "燈", "門鎖", "冷氣"]) {
            recipes.append(suggested(homeStateSummary(now: now)))
        }

        if recipes.isEmpty {
            recipes.append(suggested(KairoRecipe(
                id: "suggested-custom-recipe",
                title: "Suggested Kairo Recipe",
                summary: "Review this Kairo-owned recipe draft before enabling it.",
                createdAt: now,
                updatedAt: now,
                createdBy: .agentSuggested,
                triggerHint: .manual,
                steps: [
                    KairoRecipeStep(
                        id: "ask-kairo",
                        title: "Draft response",
                        kind: .askKairo,
                        input: .literal(request)
                    )
                ],
                requiredCapabilities: [.aiProvider],
                riskTier: .tier1Draft,
                cloudPolicy: .askEachTime,
                isEnabled: false
            )))
        }

        return recipes
    }

    private func suggested(_ recipe: KairoRecipe) -> KairoRecipe {
        var draft = recipe
        draft.createdBy = .agentSuggested
        draft.isEnabled = false
        draft.updatedAt = draft.createdAt
        return draft
    }

    private func homeStateSummary(now: Date) -> KairoRecipe {
        KairoRecipe(
            id: "home-state-summary",
            title: "Home State Summary",
            summary: "Read HomeKit state and prepare a user-confirmed action preview if needed.",
            createdAt: now,
            updatedAt: now,
            createdBy: .agentSuggested,
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "read-home",
                    title: "Read Home state",
                    kind: .readHomeState,
                    input: .shortcutInput
                ),
                KairoRecipeStep(
                    id: "home-preview",
                    title: "Prepare Home action preview",
                    kind: .proposeHomeAction,
                    input: .shortcutInput
                )
            ],
            requiredCapabilities: [.homeKit],
            riskTier: .tier3HighRiskExternal,
            cloudPolicy: .localOnly,
            isEnabled: false
        )
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}
