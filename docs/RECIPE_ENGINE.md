# Kairo Recipe Engine

> Current status: Recipes are deprioritized for the asset-management MVP. Keep existing recipe code for compatibility and tests, but do not add new recipe surfaces or sample flows unless they directly turn Library/InfoPage content into confirmed drafts or actions.

Kairo Recipes are Kairo-owned internal workflows. They are stored and run by Kairo, and they are separate from Apple Shortcuts.

## Current Scope

- Create sample internal recipes from `KairoRecipeTemplateFactory`.
- Store recipes with `InMemoryKairoRecipeStore` or `FileBackedKairoRecipeStore`.
- Preview and run recipes with `KairoRecipeRunner`.
- Enable, disable, and delete recipes through the recipe store.
- Expose a SwiftUI Shortcuts drawer screen for sample recipe install, preview, run, toggle flows, and Shortcut template install guidance.
- Expose App Intents for `Run Kairo Recipe`, `Suggest Kairo Recipe`, `List Kairo Recipes`, and `Run Kairo Daily Briefing`.

## Shortcut Boundary

Kairo does not silently create, edit, or install Apple Shortcuts. Apple Shortcuts can call Kairo App Intents such as `Run Kairo Recipe`, but Shortcut installation remains a user-approved action in the Shortcuts app.

The Shortcuts drawer screen manages internal Kairo recipes and shows `ShortcutTemplateRegistry` metadata for user-installed templates. Shortcut setup guidance and Shortcut demo node contracts stay visible, but they are not evidence that Kairo has modified the user's Shortcuts library.

## Risk Policy

Tier 0 read-only and Tier 1 draft recipes can run to produce summaries or drafts. Tier 2 low-risk writes and Tier 3 high-risk external actions require confirmation before write steps execute.

The current runner is deterministic and test-friendly:

- `askKairo` uses an injected AI provider when available, otherwise a labeled local fallback string.
- `extractTasks` uses simple line-based task extraction.
- reminder, calendar, notification, and queued action steps create `AgentAction` drafts only.
- `saveMemory` writes only to Kairo memory when the recipe is confirmed and not dry-run.
- HomeKit steps remain previews or unsupported messages until a dedicated provider is wired.

## Storage

Live app storage uses `KairoPaths.kairoRecipeStoreURL` under the shared app support directory or App Group container when available. Swift Package tests can inject temporary file URLs without iOS entitlements.

## Test Coverage

The current stage covers:

- sample recipe catalog shape and capabilities
- file-backed save/list/get/delete/toggle behavior
- runner confirmation gates for low-risk writes
- deterministic task extraction and reminder draft creation
- RootView/AutomationsView accessibility identifiers
- Shortcut template registry metadata and Shortcuts screen template identifiers
- UI smoke scenario catalog entries
- XCUITest flows for adding samples, previewing, running, disabling a recipe, and verifying Shortcut templates require user approval
