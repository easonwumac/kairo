import XCTest
@testable import KairoCore

final class KairoRecipeBackendAPITests: XCTestCase {
    func testRecipeBackendAPIForwardsLifecycleAndRunThroughInternalRecipeStore() async throws {
        let store = InMemoryKairoRecipeStore()
        let api = KairoRecipeBackendService(recipeStore: store)
        let recipe = KairoRecipe(
            id: "backend-noop-recipe",
            title: "Backend Noop Recipe",
            summary: "Exercises Kairo-owned internal recipe backend lifecycle.",
            steps: [
                KairoRecipeStep(
                    id: "noop",
                    title: "No operation",
                    kind: .noOp,
                    input: .literal("backend")
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier0ReadOnly,
            cloudPolicy: .localOnly,
            isEnabled: true
        )

        try await api.save(recipe)
        var recipes = try await api.listRecipes()
        XCTAssertEqual(recipes.map(\.id), ["backend-noop-recipe"])
        let loadedRecipe = try await api.recipe(id: "backend-noop-recipe")
        XCTAssertEqual(loadedRecipe?.title, "Backend Noop Recipe")

        let result = try await api.run(KairoRecipeRunRequest(
            recipeID: "backend-noop-recipe",
            surface: .appIntent,
            input: "Run internal recipe",
            dryRun: true,
            userConfirmed: false
        ))
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.recipeID, "backend-noop-recipe")
        XCTAssertEqual(result.proposedActions, [])

        try await api.setEnabled(false, id: "backend-noop-recipe")
        let disabledRun = try await api.run(KairoRecipeRunRequest(
            recipeID: "backend-noop-recipe",
            surface: .appIntent,
            input: nil,
            dryRun: true,
            userConfirmed: false
        ))
        XCTAssertFalse(disabledRun.success)
        XCTAssertEqual(disabledRun.errorMessage, "Recipe disabled.")

        try await api.delete(id: "backend-noop-recipe")
        recipes = try await api.listRecipes()
        XCTAssertTrue(recipes.isEmpty)
    }

    func testRecipeBackendAPISeedsKairoOwnedSamplesWithoutAppleShortcutSideEffects() async throws {
        let store = InMemoryKairoRecipeStore()
        let api = KairoRecipeBackendService(recipeStore: store)

        let samples = try await api.seedSampleRecipes()

        XCTAssertEqual(Set(samples.map(\.id)), ["daily-briefing", "meeting-prep", "shared-text-to-tasks"])
        XCTAssertTrue(samples.allSatisfy { $0.createdBy == .template })
        XCTAssertTrue(samples.allSatisfy(\.isEnabled))
        XCTAssertFalse(samples.contains { $0.requiredCapabilities.contains(.keyboard) })
    }

    func testRecipeBackendAPIUsesInjectedActionGateForRuns() async throws {
        let store = InMemoryKairoRecipeStore()
        let api = KairoRecipeBackendService(
            recipeStore: store,
            actionGate: BlockingRecipeActionGate(blockedStepKind: .noOp)
        )
        let recipe = KairoRecipe(
            id: "backend-gated-recipe",
            title: "Backend Gated Recipe",
            summary: "Verifies recipe backend dependency inversion for action gating.",
            steps: [
                KairoRecipeStep(
                    id: "gated-noop",
                    title: "Gated step",
                    kind: .noOp,
                    input: .literal("backend")
                )
            ],
            requiredCapabilities: [],
            riskTier: .tier0ReadOnly,
            cloudPolicy: .localOnly,
            isEnabled: true
        )

        try await api.save(recipe)
        let result = try await api.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: nil,
            dryRun: true,
            userConfirmed: false
        ))

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.stepResults.map(\.stepID), ["gated-noop"])
    }
}

private struct BlockingRecipeActionGate: PhoneToolActionGating {
    var blockedStepKind: KairoRecipeStepKind

    func allowsExecutablePreview(_ action: AgentAction) -> Bool {
        true
    }

    func filterExecutablePreviews(_ actions: [AgentAction]) -> [AgentAction] {
        actions
    }

    func blockedTool(for shortcutNodeKind: ShortcutNodeKind) -> BuiltInPhoneToolDefinition? {
        nil
    }

    func blockedTool(for recipeStepKind: KairoRecipeStepKind) -> BuiltInPhoneToolDefinition? {
        guard recipeStepKind == blockedStepKind else {
            return nil
        }
        var tool = BuiltInPhoneToolCatalog().tool(for: recipeStepKind)
            ?? BuiltInPhoneToolCatalog().tools[0]
        tool.availabilityStatus = .unsupported
        return tool
    }
}
