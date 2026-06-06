# Architecture

Kairo is now designed around a personal information asset library.

The architecture should make one product loop reliable:

```text
Capture -> Understand -> Organize -> Prepare confirmed actions
```

Agent/tool/skill code may remain as supporting infrastructure, but it is not the product spine. Do not expand platform abstractions unless they directly improve asset capture, Library retrieval, InfoPage generation, or confirmed action previews.

## Product Data Flow

```text
Share / Chat / App Intent / Picker
        |
        v
Capture Intake
- pending shared item
- manual note
- image/file metadata
- source reference
        |
        v
Asset Store
- KnowledgeAsset
- original resource reference
- extracted text
- tags / sensitivity
- folder links
        |
        v
Retrieval
- fuzzy text search
- date/type/folder filters
- similar assets
- candidate InfoPages
        |
        v
Understanding
- summary
- facts
- timeline
- tasks
- suggested category/folder
- create / merge / skip proposal
        |
        v
InfoPage / Library
- structured JSON
- rendered template
- linked assets
- suggested reminders/actions
        |
        v
Preview + Confirmation
- Reminder
- Calendar
- draft reply
- maps/web/phone/message visible handoff
```

## Core Objects

### `KnowledgeAsset`

The raw item the user saved or shared.

It should preserve:

- type: text, URL, image, PDF, file metadata, manual note;
- source;
- created date;
- original file/resource reference when available;
- extracted text;
- tags and sensitivity;
- linked folder and InfoPage IDs.

### `KnowledgeAssetFolder`

User-visible organization categories.

Current UX uses built-in category presets. Free-form folder creation should not be the default user path until there is a stronger management flow.

### `InfoPage`

A structured page generated from one or more assets.

MVP templates:

- Travel;
- order/booking;
- project;
- warranty;
- medical;
- finance;
- identity/document;
- general note.

Models should fill structured data. They should not invent arbitrary UI.

### `ReminderLink`

A confirmed or suggested reminder connected to an InfoPage.

Use `kairo://info-page/{id}` when possible. If a target API field does not support URLs, write the deep link into notes.

## Main Modules

| Module | Responsibility |
|---|---|
| SwiftUI App | Onboarding, Library, InfoPages, Chat review, Model Settings, Permissions, Settings. |
| Share Extension | Queue user-shared text, URLs, images, PDFs, and file metadata. No model inference or actions in the extension. |
| Knowledge Asset API | App-facing API for asset import, search, folders, delete, export, and backup policy. |
| InfoPage API | Store, generate, search, update, delete, and export structured information pages. |
| Model Settings | Cloud/local model setup used for asset understanding. |
| Retrieval Layer | Finds similar assets, folders, and InfoPages before model decisions. |
| Action Preview | Shows Reminder/Calendar/draft/handoff previews before any write or open. |
| Audit Logger | Metadata-only action records; never full sensitive payloads. |

## Storage Direction

Current implementation uses file-backed JSON stores.

Target Library node format:

```text
Library/
  index.sqlite
  folders.json
  nodes/
    <node-id>/
      node.json
      html/
        index.html
      json/
        assets.json
        info-page.json
        actions.json
      resources/
        <asset-id>.<ext>
```

Rules:

- JSON is the source of truth for structured data.
- HTML is a rendered template snapshot for viewing/export.
- `resources/` stores original images/PDFs/files only when Kairo owns the copy.
- SQLite is an index, not the only source of truth.
- iCloud backup is user-controlled from Settings.
- Never store model weights, tokenizers, caches, tokens, or credentials in Library nodes.

See `docs/ASSET_LIBRARY_STORAGE.md`.

## Model Boundary

Models are used for asset understanding:

- summarize;
- extract facts;
- classify category/folder;
- propose create/merge/skip;
- generate structured InfoPage JSON;
- suggest reminder/action drafts.

Model output must be treated as a proposal until saved by app logic.

Screenshot understanding requires real OCR/vision evidence. If a build only has metadata or mock extracted text, the UI and docs must say that.

## Safety Boundary

Kairo may prepare actions, but it must not silently execute external side effects.

Allowed:

- Share Extension intake.
- PhotosUI/camera/document picker with user-selected input.
- EventKit writes after preview and confirmation.
- UserNotifications after preview and confirmation.
- Contacts create-only after preview and confirmation when relevant.
- Visible URL handoff for mail, messages, phone, maps, and web.
- App Intents triggered by the user.
- Official API/OAuth integrations only after explicit setup.

Not allowed:

- private cross-app data reads;
- background screen watching;
- arbitrary app UI control;
- ChatGPT web-session scraping;
- silent Shortcut creation/modification;
- silent send/call/delete/write/open actions.

## Deprioritized Infrastructure

These systems may stay in the repo but should not drive new work:

- Skill marketplace;
- broad App Integration Harness catalog expansion;
- generic phone-tool platform;
- recipe/sample-flow UI;
- backend factory extraction;
- local model benchmark/platform APIs;
- Keyboard, Widget, CarPlay, HomeKit live control.

Only touch them when they directly support Library, InfoPages, model setup, or confirmed action previews.
