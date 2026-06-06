# Kairo UI Direction

## Product spine

Kairo should feel like a personal information library, not a tool console.

The first-level product path is:

1. Capture assets.
2. Review and search the Library.
3. Organize assets into InfoPages.
4. Prepare reminders, drafts, or handoffs.
5. Confirm before anything is written or opened.

## Primary navigation

Primary:

- Library.
- Chat.
- Model Settings.
- Permissions.
- Settings.

Secondary or hidden:

- Memory, until it is merged into assets/InfoPages or clearly supports Chat recall.
- Recipes, sample flows, managed tools, and integration catalogs.
- HomeKit demos and marketplace tooling.

## Visual direction

- Full-screen dark/light glass style.
- No heavy top title bars.
- Floating glass navigation buttons near the Dynamic Island.
- Page content should align under the floating navigation chrome.
- Avoid extra headings when the chrome title already establishes location.
- Lists and cards should look like a native asset library, not debug tables.

## Library

Library is the main surface.

It should show:

- Pending imported assets.
- All saved assets.
- Search and filters.
- Asset previews for text, URL, image, PDF, and files.
- Extracted text and summary when available.
- Linked InfoPages.
- Delete and export.
- iCloud backup state.

Do not bury Library behind Chat or Settings.

## InfoPages

InfoPages should be dedicated screens, not chat transcripts.

MVP template:

- Travel InfoPage with itinerary, booking facts, pickup/hotel/flight sections, missing checklist, reminders, and original assets.

Other templates can stay structured and simple:

- Order.
- Warranty.
- Project.
- Medical.
- Finance.
- Identity document.
- Home device.
- Subscription.
- General note.

## Permissions

Permissions should be a first-level list of what Kairo may suggest or use.

Use simple controls:

- Allow.
- Ask Every Time.
- Deny.

Do not show tool marketplace, manifest import, custom tools, or HomeKit demos on the first level.

## Copy rules

- Avoid implementation words: handoff, tool candidate, schema, node, scaffold, beta, source of truth.
- Do not explain unavailable features in primary UI. Hide them.
- Do not add long App Review-style disclaimers in app screens.
- If a feature is not useful or not implemented, remove or demote it instead of explaining it.

## Model settings

Model Settings supports asset understanding.

- Cloud models are added only after provider setup.
- Local models appear only after the user adds/downloads them.
- Local model detail can expose context/output/runtime parameters.
- Model tests should focus on asset summary, extraction, screenshot description, and structured InfoPage JSON.
