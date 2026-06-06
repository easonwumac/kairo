# Roadmap

Kairo's roadmap is now centered on personal information asset management.

The priority is not adding more phone-agent tools. The priority is making captured information easy to save, understand, find, and turn into confirmed reminders or drafts.

## Status labels

| Status | Meaning |
|---|---|
| Implemented | Usable in the app/core path and covered by tests for the stated scope. |
| Scaffolded | Code, UI, models, or protocols exist, but the user flow is not complete. |
| Test-only / Mock | Deterministic test/demo path only; not a real runtime capability. |
| Planned | Accepted direction, not implemented yet. |
| Deprioritized | Existing code may remain, but it should not be a primary user path. |
| Not allowed | Outside App Store-safe public API boundaries. |

## Current state

| Area | Status | Notes |
|---|---|---|
| Library navigation | Implemented | Library is a first-class drawer entry. |
| KnowledgeAsset model/store/API | Implemented | File-backed asset persistence, search, delete, export, and import from pending shares. |
| Share Extension queue | Implemented | Queues text, URL, image, PDF, and file metadata; extension remains queue-only. |
| iCloud backup policy | Implemented | Asset store exposes backup inclusion policy. |
| Library filters | Implemented | Text, type, date range, folder filters, and time grouping exist in the Library path. |
| Asset folders | Implemented | File-backed folder metadata exists; future model routing should use folder lists when deciding where to save assets. |
| Node directory layout | Planned | `html/`, `json/`, and `resources/` node storage is specified in `docs/ASSET_LIBRARY_STORAGE.md`. |
| SQLite index | Planned | Recommended when the JSON index is no longer enough for fuzzy/date/type/folder retrieval. |
| InfoPage model/store | Implemented | Codable models, file-backed store, search/delete/export. |
| InfoPage generation | Implemented | Deterministic generator for travel/order/project/general from text/extracted text. |
| Travel InfoPage UI | Scaffolded | Data model and tests exist; dedicated UI is next. |
| Asset -> InfoPage selection | Planned | Needs app UI. |
| InfoPage -> Reminder confirmation | Scaffolded | `ReminderLink` model exists; EventKit write-back UI still needs wiring. |
| Screenshot OCR / vision extraction | Planned | Do not claim image understanding until real extraction exists. |
| Chat with assets / InfoPages | Planned | Chat should search saved assets and InfoPages. |
| Model evaluation for asset understanding | Scaffolded | Evaluation catalog exists; real local vision/OCR path is not complete. |
| Recipes / sample flows | Deprioritized | Keep only if directly useful for asset-to-action flow. |
| Skill Manager / managed tools | Deprioritized | Hide from primary UI unless needed for asset workflows. |
| App Integration Harness expansion | Deprioritized | Existing safety code can support handoff previews, but catalog expansion is not the product. |
| Keyboard / Widget / CarPlay / HomeKit live control | Deprioritized | Do not start until asset-management MVP is useful. |
| Cross-app private data reads / hidden control | Not allowed | Not part of Kairo. |

## Phase 1: Asset Capture MVP

1. Make Library the obvious home for captured assets.
2. Verify Share Extension -> Asset Inbox for text, URL, screenshot/image, PDF/file metadata.
3. Preserve original asset references and extracted text.
4. Add focused UI smoke for import/list/search/delete/export.
5. Keep iCloud backup opt-in explicit.

## Phase 2: InfoPage MVP

1. Build InfoPage List.
2. Build InfoPage Detail.
3. Let users select assets and create/update an InfoPage.
4. Ship Travel template first.
5. Render fixed templates from structured data; do not ask models to invent UI.

## Phase 3: Confirmed Actions

1. Generate Reminder drafts from InfoPage facts/timeline.
2. Preview Reminder before EventKit write.
3. Confirm writes Reminder and links back to `kairo://info-page/{id}`.
4. Show linked reminder state on InfoPage.
5. Keep email/message/maps/phone/web as visible drafts or handoffs only.

## Phase 4: Asset Understanding Models

1. Define minimum JSON schema for asset extraction.
2. Evaluate text-only fallback models on OCR/user text.
3. Evaluate OCR + 2B/4B text model flows.
4. Evaluate vision-capable models for screenshot description.
5. Only expose models as usable when simulator/device evidence exists.

## Deferred

- More Shortcut nodes.
- Recipes as primary product.
- Skill marketplace.
- Generic phone-tool catalog expansion.
- Backend facade/factory/platform work.
- Local model benchmark UI/API.
- Keyboard, Widget, CarPlay.
- App icon/branding.

## Always out of scope

- Private API use.
- Jailbreak-only features.
- Arbitrary cross-app UI clicking.
- Background screen watching.
- Reading Messages, Apple Mail, Notes, Safari history/cookies, or ChatGPT web sessions.
- Silent Apple Shortcuts creation or editing.
- Silent send/call/delete/write actions.
