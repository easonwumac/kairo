# Next Steps

Kairo is now scoped to the MVP Utility Gate. Only work that directly improves one of these user flows should be started.

## App Integration Harness Scenario Evidence

Verified in focused package tests on 2026-06-05:

- Google Maps navigation request selects `googleMapsDirectionsHandoff` from `AppIntegrationSkillCatalog`, produces a confirmation-gated visible HTTPS handoff, and avoids legacy `IntegrationRegistry` duplicates.
- Google Maps unavailable state falls back to an Apple Maps catalog candidate without making the unavailable Google Maps skill executable.
- Todoist task request selects `todoistTaskAPI` from `AppIntegrationSkillCatalog`; without OAuth it remains setup-required with no executable action.
- LINE private message read request selects the LINE catalog skill as unsupported and returns a safe fallback with no executable handoff.
- Shared text import can produce reminder, calendar, and email draft previews while keeping writes and external app opens blocked before confirmation.

Evidence commands:

- `swift test --filter KairoBackendAPITests/testScenarioGoogleMapsDirectionsUsesCatalogHandoffPreview`
- `swift test --filter KairoBackendAPITests/testScenarioTodoistOAuthRequiredStaysSetupOnly`
- `swift test --filter KairoBackendAPITests/testScenarioLinePrivateDataReadUsesUnsupportedCatalogFallback`
- `swift test --filter KairoBackendAPITests/testScenarioShareImportToReminderCalendarAndEmailDraftPreviewsWithoutExecution`

## Flow A: Share -> Kairo -> Tasks / Summary

Remaining gaps:

- Verify on simulator and then a real device that shared text, URL, PDF, and file metadata appear as pending shared content in the main app.
- Confirm the user can send pending shared content into Chat without the Share Extension running inference or actions.
- Confirm Chat can summarize shared content, extract tasks, and produce reminder, calendar, and email drafts.
- Confirm every write or handoff from shared content uses preview plus explicit confirmation.
- Confirm imported share queue items are cleared after the user sends them into Chat.

Required evidence:

- Focused smoke coverage for text/URL/file metadata import into Chat.
- Focused smoke coverage for shared text -> extracted task -> reminder preview -> confirm.
- Real-device checklist entry when a reachable device is available.

## Flow B: Chat + Memory -> Action Preview

Remaining gaps:

- Verify Chat uses saved memory context in normal chats and omits it in private chats.
- Verify Chat can propose previewable actions for Reminder, Calendar, Notification, Contact, Email, Message, Phone, Web, and Maps.
- Confirm every action can be cancelled before execution.
- Confirm every supported write or handoff requires explicit confirmation before execution.
- Confirm unsupported cross-app requests produce a clear safe alternative instead of pretending to control another app.
- Confirm switching threads, deleting threads, creating a new chat, or toggling private chat clears transient action preview state.

Required evidence:

- Focused package or UI smoke coverage for Chat using memory context.
- Focused package or UI smoke coverage for action preview -> cancel and preview -> confirm.
- Real-device checklist entry for preview and confirmation when a reachable device is available.

## Flow C: Daily Briefing / Recipe

Remaining gaps:

- Verify the user can run a Daily Briefing-style Kairo Recipe from the existing Recipe surface.
- Confirm recipes only produce summaries, drafts, and suggested actions.
- Confirm high-risk recipe steps do not execute automatically.
- Confirm Shortcuts only invoke Kairo App Intents and do not silently create or modify Apple Shortcuts.

Required evidence:

- Focused smoke coverage for Daily Briefing / Recipe preview and run.
- Focused package coverage that recipe output remains draft/suggested-action only.
- Real-device checklist entry for recipe run and App Intent invocation when a reachable device is available.

## Stop Conditions

Do not start work in these categories unless it directly fixes a blocker in Flow A, Flow B, or Flow C:

- Local model backend/API expansion.
- Benchmark UI/API/runtime work.
- New Shortcut nodes.
- New Keyboard, Widget, CarPlay, HomeKit entitlement path, OAuth provider, app icon, brand assets, or release-hygiene scripts.
- General copy polish, platformization, source-health work, or large refactors.
