# Next Steps

Kairo is now scoped as a personal information asset manager and Action Inbox.
Only start work that helps users capture information, understand it, or turn it into confirmed drafts/actions.

## MVP Flow A: Capture Assets

Goal: users can send phone content into Kairo, review it in Chat, and let Kairo decide how it should enter Library.

Remaining gaps:

- Share Extension sends text, URLs, screenshots/images, PDF/file metadata into Chat review, not directly into the Library UI.
- Chat shows the shared item, runs asset retrieval, and asks whether to create, merge, or skip unless auto-create is enabled.
- Retrieval should provide similar assets, folders, and InfoPages before the model decides where the new data belongs.
- Settings should expose whether low-risk assets can be auto-created or always require confirmation.
- Main app has a clear Library entry for saved assets, filters, folders, and detail.
- Asset detail preserves original file reference, extracted text, source, date, tags, sensitivity, and linked InfoPages.
- Library supports fuzzy search, type filters, date filters, time grouping, and user-created folders.
- iCloud backup opt-in is clear and per-store behavior is testable.
- Storage nodes should move toward `html/`, `json/`, and `resources/` directories with a SQLite index when the JSON index becomes insufficient.
- Image/PDF OCR or vision extraction must be labeled unavailable until a real model/runtime path exists.

Required evidence:

- Asset Codable/store tests.
- Share queue -> Chat review -> asset proposal tests.
- Retrieval candidate tests for similar assets/folders/InfoPages.
- UI smoke for Library list/search/filter/detail/delete.
- Store/API tests for folder metadata and filtered queries.

## MVP Flow B: Organize Assets Into InfoPages

Goal: users can select assets and let Kairo build an understandable information page.

Remaining gaps:

- InfoPage List UI.
- InfoPage Detail UI.
- Select one or more assets and create or update an InfoPage.
- Travel InfoPage template first: flights, hotel/pickup/booking, timeline, reminders, original assets.
- General templates remain deterministic data renderers; models should fill structured data, not generate arbitrary UI.

Required evidence:

- InfoPage store/search/export tests.
- Asset -> InfoPage generation tests.
- Travel InfoPage template tests.
- UI smoke for create/view InfoPage from imported asset.

## MVP Flow C: InfoPage To Reminder / Action Preview

Goal: users can turn organized information into reminders or drafts without silent execution.

Remaining gaps:

- Generate Reminder drafts from InfoPage timeline/facts.
- Preview reminder before EventKit write.
- Confirm creates the Reminder and writes a Kairo deep link, preferably `kairo://info-page/{id}`.
- InfoPage displays linked reminders and current status.
- Email/message/maps/phone/web remain visible drafts or handoffs only.

Required evidence:

- Reminder deep link generation tests.
- Confirmation-required tests before EventKit writes.
- UI smoke for InfoPage -> reminder preview -> confirm.

## Model Evaluation

The local model goal is asset understanding, not benchmark UI.

- Minimum candidate: small text LLM can summarize/extract from user text and OCR text, but cannot be treated as screenshot understanding.
- Preferred candidates for screenshot/PDF understanding should support vision or pair with OCR plus a stronger text model.
- Qwen 0.8B-style models are acceptable only as fallback text extractors.
- Validate Gemma 4 E2B/E4B QAT on simulator/device for screenshot description and structured InfoPage JSON.
- Do not commit model weights, GGUF, tokenizer, cache, or generated credentials.

## Deprioritized

Do not prioritize unless it directly supports the three MVP flows:

- Recipes / sample flows.
- Skill marketplace and managed tools.
- App Integration Harness expansion.
- More Shortcut nodes.
- Keyboard, Widget, CarPlay, HomeKit live control.
- Local model platform/benchmark/backend expansion.
- Generic refactors, source-health checks, or copy polish.
