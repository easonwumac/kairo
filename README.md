# Kairo

![Kairo GitHub cover](Assets/github-readme-cover.svg)

Kairo is an open-source iOS app for personal information asset management.

The core idea is simple: users capture screenshots, links, files, notes, and messages into Kairo; Kairo turns them into searchable assets, structured information pages, reminders, drafts, and safe visible handoffs.

Kairo is not trying to be a hidden phone controller. It does not read other apps' private data, control other app UIs, or silently execute external actions. It uses public iOS paths such as Share Extension, App Intents, EventKit, UserNotifications, document/photo input, URL handoff, and explicit user confirmation.

## Product Loop

```text
Capture -> Understand -> Prepare Actions
```

### Capture

- Import text, URLs, screenshots/images, PDFs, file metadata, and manual notes.
- Keep original asset references when available.
- Store source, created date, extracted text, tags, sensitivity, and linked InfoPages.
- Organize assets by type, date, search text, and user-created folders.
- Let users choose whether imported assets participate in iCloud backup.

### Understand

- Summarize content.
- Extract tasks, dates, facts, locations, contacts, reply intent, and travel/order/project details.
- Use Kairo memory and existing assets as context.
- Prefer typed structured data over model-generated UI.

### Prepare Actions

- Create Reminder drafts.
- Create Calendar drafts.
- Prepare email/message replies.
- Prepare maps, phone, web, or external app visible handoffs.
- Save memory or link assets into InfoPages.
- Require preview and explicit confirmation before any write or external handoff.

## Main Surfaces

| Surface | Purpose |
|---|---|
| Library | Asset Inbox, asset list, search, detail, delete, export. |
| InfoPages | Organized pages such as travel, order, project, warranty, medical, finance, and documents. |
| Chat | Ask about saved assets, clarify imported content, and request drafts/actions. |
| Model Settings | Configure cloud/local models used for understanding assets. |
| Permissions | Choose what Kairo may suggest or use: allow, ask every time, or deny. |
| Settings | App-level preferences and data controls. |

Recipes, Skill Manager, phone-tool catalogs, and integration harness screens are legacy/supporting code. They should not be promoted as primary user flows unless they directly support Library, InfoPages, or confirmed action previews.

## MVP Flows

### Flow A: Screenshot or shared item to asset

The user shares a screenshot, URL, text, PDF, or file metadata into Kairo. Kairo stores it in Library, preserves the original reference when possible, and makes it searchable.

### Flow B: Assets to InfoPage

The user selects one or more assets and asks Kairo to organize them. Kairo creates or updates an InfoPage with title, category, summary, timeline, facts, linked assets, and suggested reminders.

The first dedicated template is Travel:

- Flights.
- Hotel, pickup, booking, and transport details.
- Itinerary timeline.
- Missing-item checklist.
- Reminder drafts.
- Original assets.

### Flow C: InfoPage to reminder/action

Kairo suggests reminders or drafts from an InfoPage. The user previews the action, confirms it, and Kairo writes only the confirmed item. Reminder notes should link back to `kairo://info-page/{id}` when possible.

## Current Status

### Implemented

- SwiftUI app shell with Library entry.
- Share Extension queue for text, URL, image, PDF, and file metadata.
- File-backed `KnowledgeAsset` store and backend API.
- Asset import from pending shares.
- Asset list/search/detail/delete/export.
- Library query API for fuzzy text, asset type, date range, and folder filters.
- File-backed `KnowledgeAssetFolder` metadata.
- iCloud backup policy toggle for imported assets.
- `InfoPage`, `InfoSpace`, and `ReminderLink` data models.
- File-backed `InfoPageStore`.
- Deterministic InfoPage generator for structured text/extracted text.
- Travel/order/project/general InfoPage generation paths in package tests.
- Reminder deep link model using `kairo://info-page/{id}`.
- Chat, Memory, model settings, and permissions remain available as supporting surfaces.

### Scaffolded

- InfoPage List and InfoPage Detail UI.
- Asset selection into InfoPage creation/update.
- Node directory layout with `html/`, `json/`, and `resources/`; see `docs/ASSET_LIBRARY_STORAGE.md`.
- SQLite index layer for large Library search.
- Real OCR/vision extraction for screenshots and PDFs.
- Model evaluation catalog for asset understanding.
- Confirmed EventKit write-back from InfoPage reminder drafts.

### Deprioritized

- Recipes / sample flows.
- Skill marketplace / managed tools.
- App Integration Harness expansion.
- More Shortcut nodes.
- Keyboard, Widget, CarPlay.
- HomeKit live control.
- Local model benchmark/backend platform work.

## Model Direction

Local models are important, but their job is asset understanding.

- Small text-only models can summarize and extract tasks from text or OCR output.
- Screenshot search needs OCR and/or a vision-capable model.
- Qwen 0.8B-class models should be treated as fallback text extractors, not reliable screenshot analysts.
- Gemma-class 2B/4B or similar vision/OCR-assisted models should be evaluated for screenshot description, structured JSON extraction, and InfoPage generation.
- Do not bundle or commit model weights, GGUF files, tokenizers, caches, API keys, OAuth tokens, or generated credentials.

## Safety Boundaries

Kairo does not claim capabilities that normal App Store apps cannot provide:

- No arbitrary reading of other apps' private data.
- No background screen watching or hidden screenshots.
- No unprompted control of other app UIs.
- No private APIs, jailbreak APIs, background daemons, or permission bypasses.
- No Apple Mail, Messages, Notes, Safari, or ChatGPT web-session scraping.
- No silent Apple Shortcuts creation or modification.
- No silent sending, calling, deleting, or external app execution.

Supported paths are public and user-visible:

- Share Extension for user-shared content.
- EventKit for user-confirmed reminders and calendar events.
- UserNotifications for user-confirmed local notifications.
- Contacts.framework for create-only contact actions when still relevant.
- App Intents for user-triggered automation.
- URL handoff for visible email, message, phone, web search, and maps flows.
- API key/OAuth only through official provider APIs and explicit account setup.

## Development

```bash
swift test
xcodegen generate
```

Before committing:

- Run relevant tests.
- Check `git status`.
- Scan for secrets, tokens, model weights, GGUF, tokenizers, caches, and generated credentials.
- Commit and push a small measurable stage.
