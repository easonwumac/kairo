# Kairo

![Kairo GitHub cover](Assets/github-readme-cover.svg)

Kairo is a personal information library for iPhone.

It is built for the everyday problem of saving useful things and never finding them again: screenshots, booking confirmations, receipts, URLs, PDFs, travel plans, project notes, warranty cards, medical instructions, customer messages, and random details that only matter later.

Send them to Kairo. Kairo keeps the original asset, describes what it contains, organizes it into a searchable Library, and helps turn it into reminders, checklists, drafts, or structured InfoPages.

## Why Kairo Exists

Your camera roll is not a knowledge base.

Screenshots are easy to save but hard to recover. A pickup confirmation for a Hong Kong trip, a hotel address, a return-flight reminder, a client request, or a warranty screenshot all become anonymous images mixed with everything else.

Kairo turns those scattered captures into personal information assets:

- searchable by meaning, not just filename;
- grouped into folders and InfoPages;
- linked back to the original screenshot, URL, PDF, or note;
- usable from Chat when you need to ask, “where was that thing?”;
- able to produce confirmed reminders and drafts without silently acting for you.

## Product Loop

```text
Capture -> Understand -> Organize -> Prepare Actions
```

### Capture

Import from Share Sheet, Chat, App Intents, manual notes, image picker, camera, URLs, PDFs, and file metadata.

Kairo should preserve the original asset reference whenever possible. A screenshot stays connected to the description, extracted text, source date, folder, and InfoPage it belongs to.

### Understand

Kairo extracts what matters:

- summaries;
- tasks and dates;
- travel, booking, order, warranty, project, finance, medical, and document facts;
- locations and contact/reply intent;
- links to related saved assets.

If OCR or image understanding is not actually available in a build, Kairo must say so. It should never pretend a screenshot was analyzed by a real vision model when only metadata or mock text exists.

### Organize

Saved assets live in Library.

Library is the source of truth for:

- folders/categories;
- fuzzy search;
- date grouping;
- type filters;
- asset detail;
- linked InfoPages;
- original resources;
- delete and data controls.

InfoPages turn multiple assets into a readable page. The first dedicated template is Travel: flights, pickup, hotel, bookings, itinerary, missing checklist, reminders, and original assets.

### Prepare Actions

Kairo can prepare drafts, not silently act:

- Reminder drafts;
- Calendar drafts;
- email/message replies;
- maps, phone, web visible handoffs;
- memory/asset saves;
- checklist items.

All writes and external handoffs require preview and explicit confirmation.

## Example Flow

You book an airport pickup for a Hong Kong trip and share the screenshot to Kairo.

Kairo should:

1. Store the screenshot as an asset.
2. Describe the screenshot and extract booking facts.
3. Search existing Library items for the same trip.
4. Add or merge the data into a “Hong Kong Trip” InfoPage.
5. Notice missing items, such as return transport.
6. Suggest a reminder or checklist item.
7. Write the reminder only after confirmation, with a link back to the InfoPage.

## Main Surfaces

| Surface | Purpose |
|---|---|
| Onboarding | Introduces the Library, lets users pick starter categories, then guides model setup. |
| Library | The searchable database of saved assets, folders, filters, and detail pages. |
| InfoPages | Organized pages for travel, projects, orders, warranty, medical, finance, documents, and general notes. |
| Chat | Ask about saved assets, review new captures, and request drafts/actions. |
| Model Settings | Connect cloud models or download local models used for asset understanding. |
| Permissions | Control what Kairo may suggest or use: allow, ask, or deny. |
| Settings | Appearance, iCloud backup, data deletion, and app-level preferences. |

Recipes, Skill Manager, phone-tool catalogs, and integration harness code are supporting or legacy surfaces. They should not be promoted as the primary product unless they directly help Library, InfoPages, or confirmed action previews.

## Current Status

### Implemented

- SwiftUI app shell with Chat, Library entry, Model Settings, Permissions, and Settings.
- Three-step onboarding: feature intro, starter category selection, model setup or later.
- Category/folder creation from onboarding presets.
- Share Extension queue for text, URL, image, PDF, and file metadata.
- Chat attachment intake for image picker and camera entry point.
- File-backed `KnowledgeAsset` store and backend API.
- Asset import from pending shares.
- Asset list/search/detail/delete.
- Library query API for fuzzy text, asset type, date range, and folder filters.
- File-backed `KnowledgeAssetFolder` metadata.
- iCloud backup policy toggle for imported assets.
- `InfoPage`, `InfoSpace`, and `ReminderLink` data models.
- File-backed `InfoPageStore`.
- Deterministic InfoPage generation for structured text/extracted text.
- Travel/order/project/general InfoPage generation paths in package tests.
- Reminder deep link model using `kairo://info-page/{id}`.
- User-triggered local model catalog/download/select/delete plumbing.
- API key/OAuth setup surfaces for cloud model providers.

### In Progress

- Making Library the strongest first-class surface.
- Share -> Chat review -> create/merge/skip asset proposal.
- Dedicated InfoPage List and InfoPage Detail UI.
- Travel InfoPage template UI.
- InfoPage -> Reminder preview -> confirm write.
- Real OCR / screenshot understanding.
- Local model evaluation for asset extraction quality.

### Planned

- Node storage layout with `html/`, `json/`, and `resources/`.
- SQLite index for larger Library search.
- Asset similarity retrieval before model classification.
- Per-folder backup/sync policy.
- Vision/OCR-assisted screenshot analysis.
- Stronger model evaluation for structured InfoPage JSON.

### Deprioritized

- Recipes as a primary product surface.
- Skill marketplace and managed tools.
- App Integration Harness expansion.
- More Shortcut nodes.
- Keyboard, Widget, CarPlay.
- HomeKit live control.
- Generic backend/platform refactors.
- Local model benchmark UI/API expansion.

## Model Direction

Local models are important because Kairo is a personal library, but models must serve asset understanding rather than become the product.

- Text-only small models can summarize and extract tasks from user text or OCR output.
- Screenshot understanding needs OCR, a vision-capable model, or OCR plus a stronger text model.
- Qwen 0.8B-class models should be treated as fallback text extractors, not reliable screenshot analysts.
- Gemma-class 2B/4B or similar candidates should be evaluated for screenshot description, structured JSON extraction, and InfoPage generation.
- Kairo must not bundle or commit model weights, GGUF files, tokenizers, caches, API keys, OAuth tokens, or generated credentials.

## Safety Boundaries

Kairo is not a hidden phone controller.

It does not:

- read other apps' private data;
- watch the screen in the background;
- click or control other app UIs;
- use private APIs or jailbreak-only behavior;
- scrape Mail, Messages, Notes, Safari, or ChatGPT web sessions;
- silently create or modify Apple Shortcuts;
- silently send, call, delete, write, or open external apps.

Supported paths are public and user-visible:

- Share Extension for user-shared content;
- PhotosUI / camera / document input for user-selected assets;
- EventKit for confirmed reminders/calendar events;
- UserNotifications for confirmed local notifications;
- Contacts.framework only for confirmed create flows when relevant;
- App Intents for user-triggered automation;
- URL handoff for visible email, message, phone, web, and maps flows;
- API key/OAuth only through official provider APIs and explicit account setup.

## Development

```bash
swift test
xcodegen generate
```

Before committing:

- run relevant package/UI tests;
- check `git status`;
- scan for secrets, tokens, model weights, GGUF, tokenizers, caches, and generated credentials;
- commit and push one measurable stage.
